BEGIN;

-- Table 1: weekly priority cohort entries (one row per priority entered into a given week)
CREATE TABLE IF NOT EXISTS public.founder_weekly_priorities_r2381 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  week_start date NOT NULL,
  priority_title text NOT NULL,
  priority_category text NOT NULL CHECK (priority_category IN ('product','growth','ops','finance','people','infra','external')),
  owner_user_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  effort_estimate_hours numeric(6,2) NOT NULL DEFAULT 0,
  business_impact text NOT NULL CHECK (business_impact IN ('low','medium','high','critical')),
  entered_at timestamptz NOT NULL DEFAULT now(),
  entered_by uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  notes text
);

ALTER TABLE public.founder_weekly_priorities_r2381 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_r2381_p ON public.founder_weekly_priorities_r2381;
CREATE POLICY founder_all_r2381_p ON public.founder_weekly_priorities_r2381
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

CREATE INDEX IF NOT EXISTS idx_fwp_r2381_week ON public.founder_weekly_priorities_r2381(week_start);
CREATE INDEX IF NOT EXISTS idx_fwp_r2381_cat ON public.founder_weekly_priorities_r2381(priority_category);

-- Table 2: exit/outcome events per priority
CREATE TABLE IF NOT EXISTS public.founder_priority_outcomes_r2381 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  priority_id uuid NOT NULL REFERENCES public.founder_weekly_priorities_r2381(id) ON DELETE CASCADE,
  outcome text NOT NULL CHECK (outcome IN ('shipped','dropped','deferred','still_in_progress','blocked')),
  outcome_recorded_at timestamptz NOT NULL DEFAULT now(),
  actual_effort_hours numeric(6,2),
  root_cause text NOT NULL CHECK (root_cause IN ('on_track','scope_creep','dependency_blocked','reprioritized','underestimated','external_blocker','owner_unavailable','strategy_pivot','none')),
  root_cause_detail text,
  recorded_by uuid REFERENCES public.profiles(id) ON DELETE SET NULL
);

ALTER TABLE public.founder_priority_outcomes_r2381 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_r2381_o ON public.founder_priority_outcomes_r2381;
CREATE POLICY founder_all_r2381_o ON public.founder_priority_outcomes_r2381
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

CREATE INDEX IF NOT EXISTS idx_fpo_r2381_pri ON public.founder_priority_outcomes_r2381(priority_id);
CREATE INDEX IF NOT EXISTS idx_fpo_r2381_outcome ON public.founder_priority_outcomes_r2381(outcome);

-- RPC 1: list priorities for a week with their latest outcome
DROP FUNCTION IF EXISTS public.list_weekly_priorities_r2381(date);
CREATE OR REPLACE FUNCTION public.list_weekly_priorities_r2381(p_week_start date DEFAULT NULL)
RETURNS TABLE (
  id uuid,
  week_start date,
  priority_title text,
  priority_category text,
  owner_email text,
  effort_estimate_hours numeric,
  business_impact text,
  latest_outcome text,
  root_cause text,
  actual_effort_hours numeric,
  entered_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT p.id, p.week_start, p.priority_title, p.priority_category,
         (SELECT email FROM public.profiles WHERE id = p.owner_user_id),
         p.effort_estimate_hours, p.business_impact,
         o.outcome, o.root_cause, o.actual_effort_hours, p.entered_at
  FROM public.founder_weekly_priorities_r2381 p
  LEFT JOIN LATERAL (
    SELECT outcome, root_cause, actual_effort_hours
    FROM public.founder_priority_outcomes_r2381
    WHERE priority_id = p.id
    ORDER BY outcome_recorded_at DESC
    LIMIT 1
  ) o ON true
  WHERE p_week_start IS NULL OR p.week_start = p_week_start
  ORDER BY p.week_start DESC, p.business_impact DESC;
END;
$$;

REVOKE ALL ON FUNCTION public.list_weekly_priorities_r2381(date) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_weekly_priorities_r2381(date) TO authenticated;

-- RPC 2: weekly exit-rate funnel (entered → shipped/dropped/deferred/etc.)
DROP FUNCTION IF EXISTS public.weekly_funnel_exit_rate_r2381();
CREATE OR REPLACE FUNCTION public.weekly_funnel_exit_rate_r2381()
RETURNS TABLE (
  week_start date,
  entered_count integer,
  shipped_count integer,
  dropped_count integer,
  deferred_count integer,
  still_in_progress_count integer,
  blocked_count integer,
  ship_rate_pct numeric,
  drop_rate_pct numeric
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  WITH latest AS (
    SELECT DISTINCT ON (priority_id) priority_id, outcome
    FROM public.founder_priority_outcomes_r2381
    ORDER BY priority_id, outcome_recorded_at DESC
  )
  SELECT p.week_start,
         COUNT(*)::int AS entered_count,
         COUNT(*) FILTER (WHERE l.outcome = 'shipped')::int,
         COUNT(*) FILTER (WHERE l.outcome = 'dropped')::int,
         COUNT(*) FILTER (WHERE l.outcome = 'deferred')::int,
         COUNT(*) FILTER (WHERE l.outcome = 'still_in_progress' OR l.outcome IS NULL)::int,
         COUNT(*) FILTER (WHERE l.outcome = 'blocked')::int,
         ROUND(100.0 * COUNT(*) FILTER (WHERE l.outcome = 'shipped') / NULLIF(COUNT(*),0), 1),
         ROUND(100.0 * COUNT(*) FILTER (WHERE l.outcome = 'dropped') / NULLIF(COUNT(*),0), 1)
  FROM public.founder_weekly_priorities_r2381 p
  LEFT JOIN latest l ON l.priority_id = p.id
  GROUP BY p.week_start
  ORDER BY p.week_start DESC;
END;
$$;

REVOKE ALL ON FUNCTION public.weekly_funnel_exit_rate_r2381() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.weekly_funnel_exit_rate_r2381() TO authenticated;

-- RPC 3: root-cause breakdown for non-shipped priorities
DROP FUNCTION IF EXISTS public.root_cause_breakdown_r2381();
CREATE OR REPLACE FUNCTION public.root_cause_breakdown_r2381()
RETURNS TABLE (
  root_cause text,
  priority_count integer,
  avg_effort_estimate numeric,
  pct_of_non_shipped numeric
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_total integer;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  SELECT COUNT(*) INTO v_total
  FROM public.founder_priority_outcomes_r2381 o
  WHERE o.outcome != 'shipped';
  RETURN QUERY
  SELECT o.root_cause,
         COUNT(*)::int,
         ROUND(AVG(p.effort_estimate_hours), 2),
         ROUND(100.0 * COUNT(*) / NULLIF(v_total, 0), 1)
  FROM public.founder_priority_outcomes_r2381 o
  JOIN public.founder_weekly_priorities_r2381 p ON p.id = o.priority_id
  WHERE o.outcome != 'shipped'
  GROUP BY o.root_cause
  ORDER BY COUNT(*) DESC;
END;
$$;

REVOKE ALL ON FUNCTION public.root_cause_breakdown_r2381() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.root_cause_breakdown_r2381() TO authenticated;

-- RPC 4: ship-rate by category
DROP FUNCTION IF EXISTS public.ship_rate_by_category_r2381();
CREATE OR REPLACE FUNCTION public.ship_rate_by_category_r2381()
RETURNS TABLE (
  priority_category text,
  total_priorities integer,
  shipped integer,
  dropped integer,
  ship_rate_pct numeric
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  WITH latest AS (
    SELECT DISTINCT ON (priority_id) priority_id, outcome
    FROM public.founder_priority_outcomes_r2381
    ORDER BY priority_id, outcome_recorded_at DESC
  )
  SELECT p.priority_category,
         COUNT(*)::int,
         COUNT(*) FILTER (WHERE l.outcome = 'shipped')::int,
         COUNT(*) FILTER (WHERE l.outcome = 'dropped')::int,
         ROUND(100.0 * COUNT(*) FILTER (WHERE l.outcome = 'shipped') / NULLIF(COUNT(*),0), 1)
  FROM public.founder_weekly_priorities_r2381 p
  LEFT JOIN latest l ON l.priority_id = p.id
  GROUP BY p.priority_category
  ORDER BY COUNT(*) DESC;
END;
$$;

REVOKE ALL ON FUNCTION public.ship_rate_by_category_r2381() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.ship_rate_by_category_r2381() TO authenticated;

-- RPC 5: effort variance (estimated vs actual) for shipped priorities
DROP FUNCTION IF EXISTS public.effort_variance_r2381();
CREATE OR REPLACE FUNCTION public.effort_variance_r2381()
RETURNS TABLE (
  priority_id uuid,
  priority_title text,
  week_start date,
  effort_estimate_hours numeric,
  actual_effort_hours numeric,
  variance_hours numeric,
  variance_pct numeric
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT p.id, p.priority_title, p.week_start, p.effort_estimate_hours,
         o.actual_effort_hours,
         (o.actual_effort_hours - p.effort_estimate_hours),
         ROUND(100.0 * (o.actual_effort_hours - p.effort_estimate_hours) / NULLIF(p.effort_estimate_hours, 0), 1)
  FROM public.founder_weekly_priorities_r2381 p
  JOIN public.founder_priority_outcomes_r2381 o ON o.priority_id = p.id
  WHERE o.outcome = 'shipped' AND o.actual_effort_hours IS NOT NULL
  ORDER BY ABS(COALESCE(o.actual_effort_hours,0) - p.effort_estimate_hours) DESC
  LIMIT 50;
END;
$$;

REVOKE ALL ON FUNCTION public.effort_variance_r2381() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.effort_variance_r2381() TO authenticated;

-- RPC 6: owner accountability — ship rate per owner
DROP FUNCTION IF EXISTS public.owner_ship_rate_r2381();
CREATE OR REPLACE FUNCTION public.owner_ship_rate_r2381()
RETURNS TABLE (
  owner_email text,
  total_priorities integer,
  shipped integer,
  dropped integer,
  blocked integer,
  ship_rate_pct numeric
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  WITH latest AS (
    SELECT DISTINCT ON (priority_id) priority_id, outcome
    FROM public.founder_priority_outcomes_r2381
    ORDER BY priority_id, outcome_recorded_at DESC
  )
  SELECT (SELECT email FROM public.profiles WHERE id = p.owner_user_id),
         COUNT(*)::int,
         COUNT(*) FILTER (WHERE l.outcome = 'shipped')::int,
         COUNT(*) FILTER (WHERE l.outcome = 'dropped')::int,
         COUNT(*) FILTER (WHERE l.outcome = 'blocked')::int,
         ROUND(100.0 * COUNT(*) FILTER (WHERE l.outcome = 'shipped') / NULLIF(COUNT(*),0), 1)
  FROM public.founder_weekly_priorities_r2381 p
  LEFT JOIN latest l ON l.priority_id = p.id
  WHERE p.owner_user_id IS NOT NULL
  GROUP BY p.owner_user_id
  ORDER BY COUNT(*) DESC;
END;
$$;

REVOKE ALL ON FUNCTION public.owner_ship_rate_r2381() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.owner_ship_rate_r2381() TO authenticated;

-- RPC 7: rolling 4-week trend
DROP FUNCTION IF EXISTS public.rolling_funnel_trend_r2381();
CREATE OR REPLACE FUNCTION public.rolling_funnel_trend_r2381()
RETURNS TABLE (
  bucket text,
  weeks_covered integer,
  total_priorities integer,
  total_shipped integer,
  total_dropped integer,
  rolling_ship_rate_pct numeric
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  WITH latest AS (
    SELECT DISTINCT ON (priority_id) priority_id, outcome
    FROM public.founder_priority_outcomes_r2381
    ORDER BY priority_id, outcome_recorded_at DESC
  ),
  agg AS (
    SELECT
      CASE
        WHEN p.week_start >= current_date - interval '28 days' THEN 'last_4_weeks'
        WHEN p.week_start >= current_date - interval '56 days' THEN 'prior_4_weeks'
        ELSE 'older'
      END AS bucket,
      p.week_start, p.id, l.outcome
    FROM public.founder_weekly_priorities_r2381 p
    LEFT JOIN latest l ON l.priority_id = p.id
  )
  SELECT a.bucket,
         COUNT(DISTINCT a.week_start)::int,
         COUNT(*)::int,
         COUNT(*) FILTER (WHERE a.outcome = 'shipped')::int,
         COUNT(*) FILTER (WHERE a.outcome = 'dropped')::int,
         ROUND(100.0 * COUNT(*) FILTER (WHERE a.outcome = 'shipped') / NULLIF(COUNT(*),0), 1)
  FROM agg a
  GROUP BY a.bucket
  ORDER BY CASE a.bucket WHEN 'last_4_weeks' THEN 1 WHEN 'prior_4_weeks' THEN 2 ELSE 3 END;
END;
$$;

REVOKE ALL ON FUNCTION public.rolling_funnel_trend_r2381() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.rolling_funnel_trend_r2381() TO authenticated;

COMMIT;
