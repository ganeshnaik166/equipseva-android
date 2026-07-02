BEGIN;

-- ============================================================================
-- Round 2341: Founder Sleep + Energy Tracker
-- Daily sleep hours, energy 1-10, correlation with output quality, intervention log
-- ============================================================================

-- Table 1: Daily sleep + energy log
CREATE TABLE IF NOT EXISTS public.founder_sleep_energy_log_r2341 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  founder_user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  log_date date NOT NULL DEFAULT CURRENT_DATE,
  sleep_hours numeric(4,2) NOT NULL CHECK (sleep_hours >= 0 AND sleep_hours <= 24),
  sleep_quality_rating smallint NOT NULL CHECK (sleep_quality_rating BETWEEN 1 AND 10),
  energy_morning smallint NOT NULL CHECK (energy_morning BETWEEN 1 AND 10),
  energy_afternoon smallint CHECK (energy_afternoon BETWEEN 1 AND 10),
  energy_evening smallint CHECK (energy_evening BETWEEN 1 AND 10),
  output_quality_rating smallint NOT NULL CHECK (output_quality_rating BETWEEN 1 AND 10),
  ships_count smallint NOT NULL DEFAULT 0 CHECK (ships_count >= 0),
  bugs_introduced smallint NOT NULL DEFAULT 0 CHECK (bugs_introduced >= 0),
  caffeine_mg smallint NOT NULL DEFAULT 0 CHECK (caffeine_mg >= 0),
  exercise_minutes smallint NOT NULL DEFAULT 0 CHECK (exercise_minutes >= 0),
  screen_time_hours numeric(4,2) NOT NULL DEFAULT 0 CHECK (screen_time_hours >= 0),
  mood_note text,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (founder_user_id, log_date)
);

CREATE INDEX IF NOT EXISTS idx_fsel_r2341_date ON public.founder_sleep_energy_log_r2341 (log_date DESC);
CREATE INDEX IF NOT EXISTS idx_fsel_r2341_founder ON public.founder_sleep_energy_log_r2341 (founder_user_id, log_date DESC);

ALTER TABLE public.founder_sleep_energy_log_r2341 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.founder_sleep_energy_log_r2341;
CREATE POLICY founder_all ON public.founder_sleep_energy_log_r2341
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- Table 2: Intervention log (sleep hygiene fixes, energy boosters tried)
CREATE TABLE IF NOT EXISTS public.founder_sleep_interventions_r2341 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  founder_user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  started_on date NOT NULL DEFAULT CURRENT_DATE,
  ended_on date,
  intervention_type text NOT NULL CHECK (intervention_type IN (
    'sleep_schedule', 'caffeine_cutoff', 'blue_light_block', 'magnesium',
    'meditation', 'exercise', 'cold_shower', 'screen_curfew', 'nap', 'other'
  )),
  description text NOT NULL,
  hypothesis text,
  outcome text CHECK (outcome IN ('positive', 'negative', 'neutral', 'pending')) DEFAULT 'pending',
  baseline_energy_avg numeric(4,2),
  post_energy_avg numeric(4,2),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_fsi_r2341_founder ON public.founder_sleep_interventions_r2341 (founder_user_id, started_on DESC);
CREATE INDEX IF NOT EXISTS idx_fsi_r2341_outcome ON public.founder_sleep_interventions_r2341 (outcome, started_on DESC);

ALTER TABLE public.founder_sleep_interventions_r2341 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.founder_sleep_interventions_r2341;
CREATE POLICY founder_all ON public.founder_sleep_interventions_r2341
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- ============================================================================
-- RPC 1: Recent daily log (last 30 days)
-- ============================================================================
DROP FUNCTION IF EXISTS public.founder_sleep_energy_recent_r2341();
CREATE FUNCTION public.founder_sleep_energy_recent_r2341()
RETURNS TABLE (
  log_date date,
  sleep_hours numeric,
  sleep_quality smallint,
  energy_morning smallint,
  energy_afternoon smallint,
  energy_evening smallint,
  output_quality smallint,
  ships_count smallint,
  bugs_introduced smallint,
  mood_note text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT l.log_date, l.sleep_hours, l.sleep_quality_rating, l.energy_morning,
         l.energy_afternoon, l.energy_evening, l.output_quality_rating,
         l.ships_count, l.bugs_introduced, l.mood_note
  FROM public.founder_sleep_energy_log_r2341 l
  WHERE l.log_date >= CURRENT_DATE - INTERVAL '30 days'
  ORDER BY l.log_date DESC;
END;
$$;
REVOKE ALL ON FUNCTION public.founder_sleep_energy_recent_r2341() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_sleep_energy_recent_r2341() TO authenticated;

-- ============================================================================
-- RPC 2: 7-day rolling averages
-- ============================================================================
DROP FUNCTION IF EXISTS public.founder_sleep_energy_weekly_avg_r2341();
CREATE FUNCTION public.founder_sleep_energy_weekly_avg_r2341()
RETURNS TABLE (
  metric text,
  value_7d numeric,
  value_30d numeric,
  trend text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_sleep_7 numeric; v_sleep_30 numeric;
  v_energy_7 numeric; v_energy_30 numeric;
  v_output_7 numeric; v_output_30 numeric;
  v_ships_7 numeric; v_ships_30 numeric;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  SELECT AVG(sleep_hours), AVG((energy_morning + COALESCE(energy_afternoon, energy_morning) + COALESCE(energy_evening, energy_morning))::numeric / 3),
         AVG(output_quality_rating), AVG(ships_count)
  INTO v_sleep_7, v_energy_7, v_output_7, v_ships_7
  FROM public.founder_sleep_energy_log_r2341
  WHERE log_date >= CURRENT_DATE - INTERVAL '7 days';

  SELECT AVG(sleep_hours), AVG((energy_morning + COALESCE(energy_afternoon, energy_morning) + COALESCE(energy_evening, energy_morning))::numeric / 3),
         AVG(output_quality_rating), AVG(ships_count)
  INTO v_sleep_30, v_energy_30, v_output_30, v_ships_30
  FROM public.founder_sleep_energy_log_r2341
  WHERE log_date >= CURRENT_DATE - INTERVAL '30 days';

  RETURN QUERY VALUES
    ('sleep_hours', ROUND(COALESCE(v_sleep_7, 0), 2), ROUND(COALESCE(v_sleep_30, 0), 2),
      CASE WHEN COALESCE(v_sleep_7, 0) > COALESCE(v_sleep_30, 0) THEN 'up' WHEN COALESCE(v_sleep_7, 0) < COALESCE(v_sleep_30, 0) THEN 'down' ELSE 'flat' END),
    ('energy_avg', ROUND(COALESCE(v_energy_7, 0), 2), ROUND(COALESCE(v_energy_30, 0), 2),
      CASE WHEN COALESCE(v_energy_7, 0) > COALESCE(v_energy_30, 0) THEN 'up' WHEN COALESCE(v_energy_7, 0) < COALESCE(v_energy_30, 0) THEN 'down' ELSE 'flat' END),
    ('output_quality', ROUND(COALESCE(v_output_7, 0), 2), ROUND(COALESCE(v_output_30, 0), 2),
      CASE WHEN COALESCE(v_output_7, 0) > COALESCE(v_output_30, 0) THEN 'up' WHEN COALESCE(v_output_7, 0) < COALESCE(v_output_30, 0) THEN 'down' ELSE 'flat' END),
    ('ships_per_day', ROUND(COALESCE(v_ships_7, 0), 2), ROUND(COALESCE(v_ships_30, 0), 2),
      CASE WHEN COALESCE(v_ships_7, 0) > COALESCE(v_ships_30, 0) THEN 'up' WHEN COALESCE(v_ships_7, 0) < COALESCE(v_ships_30, 0) THEN 'down' ELSE 'flat' END);
END;
$$;
REVOKE ALL ON FUNCTION public.founder_sleep_energy_weekly_avg_r2341() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_sleep_energy_weekly_avg_r2341() TO authenticated;

-- ============================================================================
-- RPC 3: Sleep -> output correlation buckets
-- ============================================================================
DROP FUNCTION IF EXISTS public.founder_sleep_output_correlation_r2341();
CREATE FUNCTION public.founder_sleep_output_correlation_r2341()
RETURNS TABLE (
  sleep_bucket text,
  log_count bigint,
  avg_output_quality numeric,
  avg_ships numeric,
  avg_bugs numeric
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    CASE
      WHEN sleep_hours < 5 THEN 'lt_5h'
      WHEN sleep_hours < 6 THEN '5_6h'
      WHEN sleep_hours < 7 THEN '6_7h'
      WHEN sleep_hours < 8 THEN '7_8h'
      ELSE 'gte_8h'
    END AS sleep_bucket,
    COUNT(*) AS log_count,
    ROUND(AVG(output_quality_rating)::numeric, 2) AS avg_output_quality,
    ROUND(AVG(ships_count)::numeric, 2) AS avg_ships,
    ROUND(AVG(bugs_introduced)::numeric, 2) AS avg_bugs
  FROM public.founder_sleep_energy_log_r2341
  WHERE log_date >= CURRENT_DATE - INTERVAL '90 days'
  GROUP BY 1
  ORDER BY 1;
END;
$$;
REVOKE ALL ON FUNCTION public.founder_sleep_output_correlation_r2341() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_sleep_output_correlation_r2341() TO authenticated;

-- ============================================================================
-- RPC 4: Energy decline alerts (3+ days low energy)
-- ============================================================================
DROP FUNCTION IF EXISTS public.founder_energy_decline_alerts_r2341();
CREATE FUNCTION public.founder_energy_decline_alerts_r2341()
RETURNS TABLE (
  log_date date,
  morning_energy smallint,
  sleep_hours numeric,
  consecutive_low_days int,
  flag text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  WITH recent AS (
    SELECT l.log_date, l.energy_morning, l.sleep_hours,
           CASE WHEN l.energy_morning <= 5 THEN 1 ELSE 0 END AS is_low
    FROM public.founder_sleep_energy_log_r2341 l
    WHERE l.log_date >= CURRENT_DATE - INTERVAL '14 days'
    ORDER BY l.log_date DESC
  ),
  streak AS (
    SELECT r.log_date, r.energy_morning, r.sleep_hours,
           SUM(r.is_low) OVER (ORDER BY r.log_date DESC ROWS BETWEEN CURRENT ROW AND 2 FOLLOWING) AS low_3d
    FROM recent r
  )
  SELECT s.log_date, s.energy_morning, s.sleep_hours, s.low_3d::int,
         CASE
           WHEN s.low_3d >= 3 THEN 'burnout_risk'
           WHEN s.energy_morning <= 4 AND s.sleep_hours < 6 THEN 'sleep_debt'
           WHEN s.energy_morning <= 5 THEN 'low_energy'
           ELSE 'ok'
         END AS flag
  FROM streak s
  WHERE s.energy_morning <= 6 OR s.low_3d >= 2
  ORDER BY s.log_date DESC;
END;
$$;
REVOKE ALL ON FUNCTION public.founder_energy_decline_alerts_r2341() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_energy_decline_alerts_r2341() TO authenticated;

-- ============================================================================
-- RPC 5: Active interventions
-- ============================================================================
DROP FUNCTION IF EXISTS public.founder_sleep_active_interventions_r2341();
CREATE FUNCTION public.founder_sleep_active_interventions_r2341()
RETURNS TABLE (
  id uuid,
  started_on date,
  days_running int,
  intervention_type text,
  description text,
  hypothesis text,
  baseline_energy numeric,
  current_energy_7d numeric,
  delta numeric
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  WITH recent_energy AS (
    SELECT AVG((energy_morning + COALESCE(energy_afternoon, energy_morning) + COALESCE(energy_evening, energy_morning))::numeric / 3) AS avg_e
    FROM public.founder_sleep_energy_log_r2341
    WHERE log_date >= CURRENT_DATE - INTERVAL '7 days'
  )
  SELECT i.id, i.started_on,
         (CURRENT_DATE - i.started_on)::int AS days_running,
         i.intervention_type, i.description, i.hypothesis,
         i.baseline_energy_avg,
         ROUND((SELECT avg_e FROM recent_energy)::numeric, 2) AS current_energy_7d,
         ROUND(((SELECT avg_e FROM recent_energy) - COALESCE(i.baseline_energy_avg, 0))::numeric, 2) AS delta
  FROM public.founder_sleep_interventions_r2341 i
  WHERE i.ended_on IS NULL
  ORDER BY i.started_on DESC;
END;
$$;
REVOKE ALL ON FUNCTION public.founder_sleep_active_interventions_r2341() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_sleep_active_interventions_r2341() TO authenticated;

-- ============================================================================
-- RPC 6: Intervention outcomes history
-- ============================================================================
DROP FUNCTION IF EXISTS public.founder_sleep_intervention_history_r2341();
CREATE FUNCTION public.founder_sleep_intervention_history_r2341()
RETURNS TABLE (
  started_on date,
  ended_on date,
  intervention_type text,
  description text,
  outcome text,
  baseline_energy numeric,
  post_energy numeric,
  delta numeric,
  notes text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT i.started_on, i.ended_on, i.intervention_type, i.description, i.outcome,
         i.baseline_energy_avg, i.post_energy_avg,
         ROUND((COALESCE(i.post_energy_avg, 0) - COALESCE(i.baseline_energy_avg, 0))::numeric, 2) AS delta,
         i.notes
  FROM public.founder_sleep_interventions_r2341 i
  WHERE i.ended_on IS NOT NULL
  ORDER BY i.ended_on DESC NULLS LAST
  LIMIT 50;
END;
$$;
REVOKE ALL ON FUNCTION public.founder_sleep_intervention_history_r2341() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_sleep_intervention_history_r2341() TO authenticated;

-- ============================================================================
-- RPC 7: KPI summary
-- ============================================================================
DROP FUNCTION IF EXISTS public.founder_sleep_energy_kpis_r2341();
CREATE FUNCTION public.founder_sleep_energy_kpis_r2341()
RETURNS TABLE (
  logs_30d bigint,
  avg_sleep_30d numeric,
  avg_energy_30d numeric,
  avg_output_30d numeric,
  low_energy_days_7d bigint,
  active_interventions bigint,
  positive_interventions_lifetime bigint,
  best_sleep_bucket text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_best text;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  SELECT bucket INTO v_best FROM (
    SELECT
      CASE
        WHEN sleep_hours < 6 THEN 'lt_6h'
        WHEN sleep_hours < 7 THEN '6_7h'
        WHEN sleep_hours < 8 THEN '7_8h'
        ELSE 'gte_8h'
      END AS bucket,
      AVG(output_quality_rating) AS q
    FROM public.founder_sleep_energy_log_r2341
    WHERE log_date >= CURRENT_DATE - INTERVAL '90 days'
    GROUP BY 1
    ORDER BY q DESC NULLS LAST
    LIMIT 1
  ) t;

  RETURN QUERY
  SELECT
    (SELECT COUNT(*) FROM public.founder_sleep_energy_log_r2341 WHERE log_date >= CURRENT_DATE - INTERVAL '30 days'),
    ROUND(COALESCE((SELECT AVG(sleep_hours) FROM public.founder_sleep_energy_log_r2341 WHERE log_date >= CURRENT_DATE - INTERVAL '30 days'), 0)::numeric, 2),
    ROUND(COALESCE((SELECT AVG((energy_morning + COALESCE(energy_afternoon, energy_morning) + COALESCE(energy_evening, energy_morning))::numeric / 3) FROM public.founder_sleep_energy_log_r2341 WHERE log_date >= CURRENT_DATE - INTERVAL '30 days'), 0)::numeric, 2),
    ROUND(COALESCE((SELECT AVG(output_quality_rating) FROM public.founder_sleep_energy_log_r2341 WHERE log_date >= CURRENT_DATE - INTERVAL '30 days'), 0)::numeric, 2),
    (SELECT COUNT(*) FROM public.founder_sleep_energy_log_r2341 WHERE log_date >= CURRENT_DATE - INTERVAL '7 days' AND energy_morning <= 5),
    (SELECT COUNT(*) FROM public.founder_sleep_interventions_r2341 WHERE ended_on IS NULL),
    (SELECT COUNT(*) FROM public.founder_sleep_interventions_r2341 WHERE outcome = 'positive'),
    COALESCE(v_best, 'no_data');
END;
$$;
REVOKE ALL ON FUNCTION public.founder_sleep_energy_kpis_r2341() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_sleep_energy_kpis_r2341() TO authenticated;

COMMIT;
