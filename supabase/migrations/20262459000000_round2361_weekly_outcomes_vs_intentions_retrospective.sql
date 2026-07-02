BEGIN;

CREATE TABLE IF NOT EXISTS public.founder_weekly_intentions_r2361 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  week_start date NOT NULL,
  intention_title text NOT NULL,
  intention_category text NOT NULL CHECK (intention_category IN ('product','growth','ops','fundraise','hiring','personal','strategy')),
  intention_description text,
  priority text NOT NULL DEFAULT 'medium' CHECK (priority IN ('p0','p1','p2','p3')),
  success_metric text,
  target_value numeric,
  declared_at timestamptz NOT NULL DEFAULT now(),
  declared_by uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.founder_weekly_outcomes_r2361 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  intention_id uuid NOT NULL REFERENCES public.founder_weekly_intentions_r2361(id) ON DELETE CASCADE,
  outcome_status text NOT NULL CHECK (outcome_status IN ('completed','partial','missed','deferred','obsolete')),
  outcome_notes text,
  actual_value numeric,
  gap_reason text,
  blocking_factor text,
  lesson_learned text,
  recorded_at timestamptz NOT NULL DEFAULT now(),
  recorded_by uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_fwi_r2361_week ON public.founder_weekly_intentions_r2361(week_start DESC);
CREATE INDEX IF NOT EXISTS idx_fwo_r2361_intention ON public.founder_weekly_outcomes_r2361(intention_id);

ALTER TABLE public.founder_weekly_intentions_r2361 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.founder_weekly_outcomes_r2361 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS fwi_r2361_founder_all ON public.founder_weekly_intentions_r2361;
CREATE POLICY fwi_r2361_founder_all ON public.founder_weekly_intentions_r2361 FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS fwo_r2361_founder_all ON public.founder_weekly_outcomes_r2361;
CREATE POLICY fwo_r2361_founder_all ON public.founder_weekly_outcomes_r2361 FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

CREATE OR REPLACE FUNCTION public.founder_retro_week_summary_r2361(p_weeks int DEFAULT 12)
RETURNS TABLE(week_start date, total_intentions int, completed int, partial int, missed int, deferred int, hit_rate numeric)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT i.week_start,
         COUNT(*)::int,
         COUNT(*) FILTER (WHERE o.outcome_status='completed')::int,
         COUNT(*) FILTER (WHERE o.outcome_status='partial')::int,
         COUNT(*) FILTER (WHERE o.outcome_status='missed')::int,
         COUNT(*) FILTER (WHERE o.outcome_status='deferred')::int,
         ROUND(100.0 * COUNT(*) FILTER (WHERE o.outcome_status='completed') / NULLIF(COUNT(*),0), 1)
  FROM public.founder_weekly_intentions_r2361 i
  LEFT JOIN public.founder_weekly_outcomes_r2361 o ON o.intention_id=i.id
  WHERE i.week_start >= (CURRENT_DATE - (p_weeks||' weeks')::interval)::date
  GROUP BY i.week_start
  ORDER BY i.week_start DESC;
END $$;

CREATE OR REPLACE FUNCTION public.founder_retro_current_week_r2361()
RETURNS TABLE(id uuid, intention_title text, category text, priority text, success_metric text, target_value numeric, outcome_status text, actual_value numeric, gap_reason text)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT i.id, i.intention_title, i.intention_category, i.priority, i.success_metric, i.target_value,
         COALESCE(o.outcome_status,'pending'), o.actual_value, o.gap_reason
  FROM public.founder_weekly_intentions_r2361 i
  LEFT JOIN public.founder_weekly_outcomes_r2361 o ON o.intention_id=i.id
  WHERE i.week_start = date_trunc('week', CURRENT_DATE)::date
  ORDER BY i.priority, i.declared_at DESC;
END $$;

CREATE OR REPLACE FUNCTION public.founder_retro_category_hitrate_r2361()
RETURNS TABLE(category text, total int, completed int, hit_rate numeric)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT i.intention_category,
         COUNT(*)::int,
         COUNT(*) FILTER (WHERE o.outcome_status='completed')::int,
         ROUND(100.0 * COUNT(*) FILTER (WHERE o.outcome_status='completed') / NULLIF(COUNT(*),0), 1)
  FROM public.founder_weekly_intentions_r2361 i
  LEFT JOIN public.founder_weekly_outcomes_r2361 o ON o.intention_id=i.id
  GROUP BY i.intention_category
  ORDER BY 4 DESC NULLS LAST;
END $$;

CREATE OR REPLACE FUNCTION public.founder_retro_blocking_factors_r2361()
RETURNS TABLE(blocking_factor text, occurrences int, last_seen date)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT o.blocking_factor, COUNT(*)::int, MAX(i.week_start)
  FROM public.founder_weekly_outcomes_r2361 o
  JOIN public.founder_weekly_intentions_r2361 i ON i.id=o.intention_id
  WHERE o.blocking_factor IS NOT NULL
  GROUP BY o.blocking_factor
  ORDER BY 2 DESC LIMIT 25;
END $$;

CREATE OR REPLACE FUNCTION public.founder_retro_recent_lessons_r2361()
RETURNS TABLE(week_start date, intention_title text, lesson_learned text, outcome_status text)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT i.week_start, i.intention_title, o.lesson_learned, o.outcome_status
  FROM public.founder_weekly_outcomes_r2361 o
  JOIN public.founder_weekly_intentions_r2361 i ON i.id=o.intention_id
  WHERE o.lesson_learned IS NOT NULL
  ORDER BY i.week_start DESC, o.recorded_at DESC LIMIT 50;
END $$;

CREATE OR REPLACE FUNCTION public.founder_retro_missed_streak_r2361()
RETURNS TABLE(intention_title text, category text, consecutive_misses int, last_week date)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT i.intention_title, i.intention_category,
         COUNT(*)::int, MAX(i.week_start)
  FROM public.founder_weekly_intentions_r2361 i
  JOIN public.founder_weekly_outcomes_r2361 o ON o.intention_id=i.id
  WHERE o.outcome_status IN ('missed','deferred')
  GROUP BY i.intention_title, i.intention_category
  HAVING COUNT(*) >= 2
  ORDER BY 3 DESC LIMIT 25;
END $$;

CREATE OR REPLACE FUNCTION public.founder_retro_kpi_r2361()
RETURNS TABLE(total_weeks int, total_intentions int, overall_hit_rate numeric, avg_intentions_per_week numeric, pending_current_week int)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT COUNT(DISTINCT i.week_start)::int,
         COUNT(*)::int,
         ROUND(100.0 * COUNT(*) FILTER (WHERE o.outcome_status='completed') / NULLIF(COUNT(o.id),0), 1),
         ROUND(COUNT(*)::numeric / NULLIF(COUNT(DISTINCT i.week_start),0), 1),
         COUNT(*) FILTER (WHERE i.week_start = date_trunc('week', CURRENT_DATE)::date AND o.id IS NULL)::int
  FROM public.founder_weekly_intentions_r2361 i
  LEFT JOIN public.founder_weekly_outcomes_r2361 o ON o.intention_id=i.id;
END $$;

REVOKE ALL ON FUNCTION public.founder_retro_week_summary_r2361(int) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.founder_retro_current_week_r2361() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.founder_retro_category_hitrate_r2361() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.founder_retro_blocking_factors_r2361() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.founder_retro_recent_lessons_r2361() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.founder_retro_missed_streak_r2361() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.founder_retro_kpi_r2361() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.founder_retro_week_summary_r2361(int) TO authenticated;
GRANT EXECUTE ON FUNCTION public.founder_retro_current_week_r2361() TO authenticated;
GRANT EXECUTE ON FUNCTION public.founder_retro_category_hitrate_r2361() TO authenticated;
GRANT EXECUTE ON FUNCTION public.founder_retro_blocking_factors_r2361() TO authenticated;
GRANT EXECUTE ON FUNCTION public.founder_retro_recent_lessons_r2361() TO authenticated;
GRANT EXECUTE ON FUNCTION public.founder_retro_missed_streak_r2361() TO authenticated;
GRANT EXECUTE ON FUNCTION public.founder_retro_kpi_r2361() TO authenticated;

COMMIT;
