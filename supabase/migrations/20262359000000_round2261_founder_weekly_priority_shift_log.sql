BEGIN;

CREATE TABLE IF NOT EXISTS public.founder_weekly_priority_shifts_r2261 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  week_start date NOT NULL,
  prior_week_start date NOT NULL,
  priority_area text NOT NULL CHECK (priority_area IN ('payouts','amc','engineer_ops','hospital_chain','compliance','investor','marketplace','support','field_quality','growth')),
  prior_rank int NOT NULL CHECK (prior_rank BETWEEN 1 AND 20),
  current_rank int NOT NULL CHECK (current_rank BETWEEN 1 AND 20),
  shift_direction text NOT NULL CHECK (shift_direction IN ('up','down','new','dropped','unchanged')),
  shift_magnitude int NOT NULL DEFAULT 0,
  rationale text NOT NULL,
  catalyst_event text,
  decided_by uuid REFERENCES public.profiles(id),
  decided_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.founder_priority_shift_impact_r2261 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  shift_id uuid NOT NULL REFERENCES public.founder_weekly_priority_shifts_r2261(id) ON DELETE CASCADE,
  impact_area text NOT NULL CHECK (impact_area IN ('engineering','ops','finance','sales','support','founder_time','external_partner')),
  impact_kind text NOT NULL CHECK (impact_kind IN ('resource_reallocation','meeting_cadence','hiring','vendor_change','process_change','tool_change','comms')),
  description text NOT NULL,
  observed_outcome text,
  outcome_status text NOT NULL DEFAULT 'pending' CHECK (outcome_status IN ('pending','positive','neutral','negative')),
  recorded_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.founder_weekly_priority_shifts_r2261 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.founder_priority_shift_impact_r2261 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.founder_weekly_priority_shifts_r2261;
CREATE POLICY founder_all ON public.founder_weekly_priority_shifts_r2261 FOR ALL USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all ON public.founder_priority_shift_impact_r2261;
CREATE POLICY founder_all ON public.founder_priority_shift_impact_r2261 FOR ALL USING (public.is_founder()) WITH CHECK (public.is_founder());

CREATE INDEX IF NOT EXISTS idx_r2261_shifts_week ON public.founder_weekly_priority_shifts_r2261(week_start DESC);
CREATE INDEX IF NOT EXISTS idx_r2261_shifts_area ON public.founder_weekly_priority_shifts_r2261(priority_area);
CREATE INDEX IF NOT EXISTS idx_r2261_impact_shift ON public.founder_priority_shift_impact_r2261(shift_id);

CREATE OR REPLACE FUNCTION public.founder_priority_shift_summary_r2261()
RETURNS TABLE(total_shifts int, weeks_logged int, areas_tracked int, avg_magnitude numeric, last_logged_week date)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    COUNT(*)::int,
    COUNT(DISTINCT week_start)::int,
    COUNT(DISTINCT priority_area)::int,
    COALESCE(ROUND(AVG(shift_magnitude)::numeric, 2), 0),
    MAX(week_start)
  FROM public.founder_weekly_priority_shifts_r2261;
END; $$;

CREATE OR REPLACE FUNCTION public.founder_priority_shift_recent_r2261()
RETURNS TABLE(week_start date, priority_area text, prior_rank int, current_rank int, shift_direction text, shift_magnitude int, rationale text)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT s.week_start, s.priority_area, s.prior_rank, s.current_rank, s.shift_direction, s.shift_magnitude, s.rationale
  FROM public.founder_weekly_priority_shifts_r2261 s
  ORDER BY s.week_start DESC, s.shift_magnitude DESC
  LIMIT 50;
END; $$;

CREATE OR REPLACE FUNCTION public.founder_priority_shift_by_area_r2261()
RETURNS TABLE(priority_area text, shift_count int, avg_magnitude numeric, up_moves int, down_moves int)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    s.priority_area,
    COUNT(*)::int,
    COALESCE(ROUND(AVG(s.shift_magnitude)::numeric, 2), 0),
    (COUNT(*) FILTER (WHERE s.shift_direction = 'up'))::int,
    (COUNT(*) FILTER (WHERE s.shift_direction = 'down'))::int
  FROM public.founder_weekly_priority_shifts_r2261 s
  GROUP BY s.priority_area
  ORDER BY COUNT(*) DESC;
END; $$;

CREATE OR REPLACE FUNCTION public.founder_priority_shift_direction_breakdown_r2261()
RETURNS TABLE(shift_direction text, count_shifts int, pct_share numeric)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE total int;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  SELECT COUNT(*) INTO total FROM public.founder_weekly_priority_shifts_r2261;
  RETURN QUERY
  SELECT
    s.shift_direction,
    COUNT(*)::int,
    CASE WHEN total > 0 THEN ROUND((COUNT(*)::numeric / total) * 100, 2) ELSE 0 END
  FROM public.founder_weekly_priority_shifts_r2261 s
  GROUP BY s.shift_direction
  ORDER BY COUNT(*) DESC;
END; $$;

CREATE OR REPLACE FUNCTION public.founder_priority_shift_top_movers_r2261()
RETURNS TABLE(week_start date, priority_area text, shift_direction text, shift_magnitude int, rationale text)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT s.week_start, s.priority_area, s.shift_direction, s.shift_magnitude, s.rationale
  FROM public.founder_weekly_priority_shifts_r2261 s
  WHERE s.shift_magnitude > 0
  ORDER BY s.shift_magnitude DESC, s.week_start DESC
  LIMIT 25;
END; $$;

CREATE OR REPLACE FUNCTION public.founder_priority_shift_impact_summary_r2261()
RETURNS TABLE(impact_area text, total_impacts int, positive_outcomes int, negative_outcomes int, pending_outcomes int)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    i.impact_area,
    COUNT(*)::int,
    (COUNT(*) FILTER (WHERE i.outcome_status = 'positive'))::int,
    (COUNT(*) FILTER (WHERE i.outcome_status = 'negative'))::int,
    (COUNT(*) FILTER (WHERE i.outcome_status = 'pending'))::int
  FROM public.founder_priority_shift_impact_r2261 i
  GROUP BY i.impact_area
  ORDER BY COUNT(*) DESC;
END; $$;

CREATE OR REPLACE FUNCTION public.founder_priority_shift_weekly_trend_r2261()
RETURNS TABLE(week_start date, shifts_count int, avg_magnitude numeric, new_priorities int, dropped_priorities int)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    s.week_start,
    COUNT(*)::int,
    COALESCE(ROUND(AVG(s.shift_magnitude)::numeric, 2), 0),
    (COUNT(*) FILTER (WHERE s.shift_direction = 'new'))::int,
    (COUNT(*) FILTER (WHERE s.shift_direction = 'dropped'))::int
  FROM public.founder_weekly_priority_shifts_r2261 s
  GROUP BY s.week_start
  ORDER BY s.week_start DESC
  LIMIT 12;
END; $$;

REVOKE ALL ON FUNCTION public.founder_priority_shift_summary_r2261() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.founder_priority_shift_recent_r2261() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.founder_priority_shift_by_area_r2261() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.founder_priority_shift_direction_breakdown_r2261() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.founder_priority_shift_top_movers_r2261() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.founder_priority_shift_impact_summary_r2261() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.founder_priority_shift_weekly_trend_r2261() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.founder_priority_shift_summary_r2261() TO authenticated;
GRANT EXECUTE ON FUNCTION public.founder_priority_shift_recent_r2261() TO authenticated;
GRANT EXECUTE ON FUNCTION public.founder_priority_shift_by_area_r2261() TO authenticated;
GRANT EXECUTE ON FUNCTION public.founder_priority_shift_direction_breakdown_r2261() TO authenticated;
GRANT EXECUTE ON FUNCTION public.founder_priority_shift_top_movers_r2261() TO authenticated;
GRANT EXECUTE ON FUNCTION public.founder_priority_shift_impact_summary_r2261() TO authenticated;
GRANT EXECUTE ON FUNCTION public.founder_priority_shift_weekly_trend_r2261() TO authenticated;

COMMIT;
