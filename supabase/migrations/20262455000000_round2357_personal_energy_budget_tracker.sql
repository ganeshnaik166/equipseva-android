BEGIN;

CREATE TABLE IF NOT EXISTS public.founder_energy_spend_r2357 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  founder_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  spend_date date NOT NULL,
  category text NOT NULL CHECK (category IN ('meetings','deep_work','calls','email','admin','travel','recovery')),
  energy_units integer NOT NULL CHECK (energy_units BETWEEN 0 AND 100),
  duration_minutes integer NOT NULL DEFAULT 0 CHECK (duration_minutes >= 0),
  perceived_drain text NOT NULL DEFAULT 'medium' CHECK (perceived_drain IN ('low','medium','high','extreme')),
  note text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_energy_spend_r2357_founder_date ON public.founder_energy_spend_r2357(founder_id, spend_date DESC);
CREATE INDEX IF NOT EXISTS idx_energy_spend_r2357_category ON public.founder_energy_spend_r2357(category);

ALTER TABLE public.founder_energy_spend_r2357 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.founder_energy_spend_r2357;
CREATE POLICY founder_all ON public.founder_energy_spend_r2357
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

CREATE TABLE IF NOT EXISTS public.founder_energy_budget_r2357 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  founder_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  budget_date date NOT NULL,
  daily_budget_units integer NOT NULL DEFAULT 100 CHECK (daily_budget_units BETWEEN 0 AND 500),
  surplus_deficit integer NOT NULL DEFAULT 0,
  reflection text,
  recovery_planned text,
  closed_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (founder_id, budget_date)
);

CREATE INDEX IF NOT EXISTS idx_energy_budget_r2357_founder_date ON public.founder_energy_budget_r2357(founder_id, budget_date DESC);

ALTER TABLE public.founder_energy_budget_r2357 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.founder_energy_budget_r2357;
CREATE POLICY founder_all ON public.founder_energy_budget_r2357
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- RPC 1: today snapshot
CREATE OR REPLACE FUNCTION public.founder_energy_today_r2357()
RETURNS TABLE (
  spend_date date,
  daily_budget_units integer,
  total_spent integer,
  surplus_deficit integer,
  entries_logged bigint,
  top_category text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  WITH today AS (
    SELECT CURRENT_DATE AS d
  ),
  spent AS (
    SELECT COALESCE(SUM(energy_units),0)::int AS total, COUNT(*)::bigint AS cnt
    FROM public.founder_energy_spend_r2357 s, today
    WHERE s.spend_date = today.d
  ),
  budget AS (
    SELECT COALESCE(b.daily_budget_units, 100) AS bud
    FROM today LEFT JOIN public.founder_energy_budget_r2357 b
      ON b.budget_date = today.d
    LIMIT 1
  ),
  top_cat AS (
    SELECT s.category, SUM(s.energy_units) AS u
    FROM public.founder_energy_spend_r2357 s, today
    WHERE s.spend_date = today.d
    GROUP BY s.category
    ORDER BY u DESC NULLS LAST
    LIMIT 1
  )
  SELECT
    (SELECT d FROM today),
    (SELECT bud FROM budget)::int,
    (SELECT total FROM spent),
    ((SELECT bud FROM budget) - (SELECT total FROM spent))::int,
    (SELECT cnt FROM spent),
    (SELECT category FROM top_cat);
END;
$$;

REVOKE ALL ON FUNCTION public.founder_energy_today_r2357() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_energy_today_r2357() TO authenticated;

-- RPC 2: recent spend entries
CREATE OR REPLACE FUNCTION public.founder_energy_recent_spend_r2357()
RETURNS TABLE (
  id uuid,
  spend_date date,
  category text,
  energy_units integer,
  duration_minutes integer,
  perceived_drain text,
  note text,
  created_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT s.id, s.spend_date, s.category, s.energy_units, s.duration_minutes,
         s.perceived_drain, s.note, s.created_at
  FROM public.founder_energy_spend_r2357 s
  WHERE s.spend_date >= CURRENT_DATE - INTERVAL '14 days'
  ORDER BY s.spend_date DESC, s.created_at DESC
  LIMIT 100;
END;
$$;

REVOKE ALL ON FUNCTION public.founder_energy_recent_spend_r2357() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_energy_recent_spend_r2357() TO authenticated;

-- RPC 3: category breakdown (7 days)
CREATE OR REPLACE FUNCTION public.founder_energy_category_breakdown_r2357()
RETURNS TABLE (
  category text,
  total_units bigint,
  total_minutes bigint,
  entries bigint,
  avg_units numeric,
  high_drain_pct numeric
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    s.category,
    SUM(s.energy_units)::bigint,
    SUM(s.duration_minutes)::bigint,
    COUNT(*)::bigint,
    ROUND(AVG(s.energy_units)::numeric, 1),
    ROUND(100.0 * SUM(CASE WHEN s.perceived_drain IN ('high','extreme') THEN 1 ELSE 0 END) / NULLIF(COUNT(*),0), 1)
  FROM public.founder_energy_spend_r2357 s
  WHERE s.spend_date >= CURRENT_DATE - INTERVAL '7 days'
  GROUP BY s.category
  ORDER BY SUM(s.energy_units) DESC;
END;
$$;

REVOKE ALL ON FUNCTION public.founder_energy_category_breakdown_r2357() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_energy_category_breakdown_r2357() TO authenticated;

-- RPC 4: daily totals last 14 days
CREATE OR REPLACE FUNCTION public.founder_energy_daily_totals_r2357()
RETURNS TABLE (
  day date,
  total_spent bigint,
  daily_budget integer,
  surplus_deficit integer,
  entries bigint,
  status text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  WITH days AS (
    SELECT (CURRENT_DATE - i)::date AS d
    FROM generate_series(0, 13) AS g(i)
  ),
  sp AS (
    SELECT s.spend_date AS d, SUM(s.energy_units)::bigint AS total, COUNT(*)::bigint AS cnt
    FROM public.founder_energy_spend_r2357 s
    WHERE s.spend_date >= CURRENT_DATE - INTERVAL '13 days'
    GROUP BY s.spend_date
  )
  SELECT
    days.d,
    COALESCE(sp.total, 0),
    COALESCE(b.daily_budget_units, 100),
    (COALESCE(b.daily_budget_units, 100) - COALESCE(sp.total, 0))::int,
    COALESCE(sp.cnt, 0),
    CASE
      WHEN COALESCE(sp.total,0) = 0 THEN 'no_log'
      WHEN COALESCE(sp.total,0) > COALESCE(b.daily_budget_units, 100) THEN 'deficit'
      WHEN COALESCE(sp.total,0) > 0.8 * COALESCE(b.daily_budget_units, 100) THEN 'tight'
      ELSE 'surplus'
    END
  FROM days
  LEFT JOIN sp ON sp.d = days.d
  LEFT JOIN public.founder_energy_budget_r2357 b ON b.budget_date = days.d
  ORDER BY days.d DESC;
END;
$$;

REVOKE ALL ON FUNCTION public.founder_energy_daily_totals_r2357() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_energy_daily_totals_r2357() TO authenticated;

-- RPC 5: drain level distribution
CREATE OR REPLACE FUNCTION public.founder_energy_drain_distribution_r2357()
RETURNS TABLE (
  perceived_drain text,
  entries bigint,
  total_units bigint,
  pct_of_total numeric
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_total bigint;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  SELECT COALESCE(SUM(energy_units),0)::bigint INTO v_total
  FROM public.founder_energy_spend_r2357
  WHERE spend_date >= CURRENT_DATE - INTERVAL '7 days';

  RETURN QUERY
  SELECT
    s.perceived_drain,
    COUNT(*)::bigint,
    SUM(s.energy_units)::bigint,
    CASE WHEN v_total = 0 THEN 0::numeric
         ELSE ROUND(100.0 * SUM(s.energy_units) / v_total, 1) END
  FROM public.founder_energy_spend_r2357 s
  WHERE s.spend_date >= CURRENT_DATE - INTERVAL '7 days'
  GROUP BY s.perceived_drain
  ORDER BY SUM(s.energy_units) DESC;
END;
$$;

REVOKE ALL ON FUNCTION public.founder_energy_drain_distribution_r2357() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_energy_drain_distribution_r2357() TO authenticated;

-- RPC 6: budget reflections (recent closed days)
CREATE OR REPLACE FUNCTION public.founder_energy_reflections_r2357()
RETURNS TABLE (
  budget_date date,
  daily_budget_units integer,
  surplus_deficit integer,
  reflection text,
  recovery_planned text,
  closed_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT b.budget_date, b.daily_budget_units, b.surplus_deficit, b.reflection,
         b.recovery_planned, b.closed_at
  FROM public.founder_energy_budget_r2357 b
  WHERE b.closed_at IS NOT NULL
  ORDER BY b.budget_date DESC
  LIMIT 30;
END;
$$;

REVOKE ALL ON FUNCTION public.founder_energy_reflections_r2357() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_energy_reflections_r2357() TO authenticated;

-- RPC 7: rolling 7-day stats
CREATE OR REPLACE FUNCTION public.founder_energy_rolling_stats_r2357()
RETURNS TABLE (
  window_days integer,
  total_units bigint,
  avg_daily numeric,
  days_in_deficit bigint,
  days_logged bigint,
  highest_day date,
  highest_units bigint
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  WITH daily AS (
    SELECT s.spend_date AS d, SUM(s.energy_units)::bigint AS total
    FROM public.founder_energy_spend_r2357 s
    WHERE s.spend_date >= CURRENT_DATE - INTERVAL '7 days'
    GROUP BY s.spend_date
  ),
  joined AS (
    SELECT daily.d, daily.total,
           COALESCE(b.daily_budget_units, 100) AS bud
    FROM daily
    LEFT JOIN public.founder_energy_budget_r2357 b ON b.budget_date = daily.d
  ),
  highest AS (
    SELECT d, total FROM daily ORDER BY total DESC NULLS LAST LIMIT 1
  )
  SELECT
    7,
    COALESCE((SELECT SUM(total) FROM daily), 0)::bigint,
    COALESCE(ROUND((SELECT AVG(total) FROM daily)::numeric, 1), 0::numeric),
    COALESCE((SELECT COUNT(*) FROM joined WHERE total > bud), 0)::bigint,
    COALESCE((SELECT COUNT(*) FROM daily), 0)::bigint,
    (SELECT d FROM highest),
    COALESCE((SELECT total FROM highest), 0)::bigint;
END;
$$;

REVOKE ALL ON FUNCTION public.founder_energy_rolling_stats_r2357() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_energy_rolling_stats_r2357() TO authenticated;

COMMIT;
