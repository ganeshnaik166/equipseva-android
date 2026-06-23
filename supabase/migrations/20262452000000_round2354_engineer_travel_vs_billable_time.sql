BEGIN;

CREATE TABLE IF NOT EXISTS public.engineer_travel_time_logs_r2354 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  log_date date NOT NULL,
  city text NOT NULL,
  region text NOT NULL,
  shift_start_at timestamptz NOT NULL,
  shift_end_at timestamptz NOT NULL,
  total_shift_minutes integer NOT NULL CHECK (total_shift_minutes >= 0),
  travel_minutes integer NOT NULL DEFAULT 0 CHECK (travel_minutes >= 0),
  billable_minutes integer NOT NULL DEFAULT 0 CHECK (billable_minutes >= 0),
  idle_minutes integer NOT NULL DEFAULT 0 CHECK (idle_minutes >= 0),
  admin_minutes integer NOT NULL DEFAULT 0 CHECK (admin_minutes >= 0),
  distance_km numeric(10,2) NOT NULL DEFAULT 0 CHECK (distance_km >= 0),
  jobs_completed integer NOT NULL DEFAULT 0 CHECK (jobs_completed >= 0),
  fuel_cost_rupees integer NOT NULL DEFAULT 0 CHECK (fuel_cost_rupees >= 0),
  revenue_generated_rupees integer NOT NULL DEFAULT 0 CHECK (revenue_generated_rupees >= 0),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (engineer_id, log_date)
);

CREATE INDEX IF NOT EXISTS idx_ettl_r2354_engineer ON public.engineer_travel_time_logs_r2354(engineer_id);
CREATE INDEX IF NOT EXISTS idx_ettl_r2354_date ON public.engineer_travel_time_logs_r2354(log_date);
CREATE INDEX IF NOT EXISTS idx_ettl_r2354_city ON public.engineer_travel_time_logs_r2354(city);
CREATE INDEX IF NOT EXISTS idx_ettl_r2354_region ON public.engineer_travel_time_logs_r2354(region);

ALTER TABLE public.engineer_travel_time_logs_r2354 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.engineer_travel_time_logs_r2354;
CREATE POLICY founder_all ON public.engineer_travel_time_logs_r2354
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

CREATE TABLE IF NOT EXISTS public.engineer_travel_optimization_actions_r2354 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  city text NOT NULL,
  region text NOT NULL,
  action_type text NOT NULL CHECK (action_type IN ('route_reassignment','cluster_rebalance','hub_relocation','schedule_change','vehicle_swap','training','other')),
  action_summary text NOT NULL,
  expected_minutes_saved integer NOT NULL DEFAULT 0,
  expected_rupees_saved integer NOT NULL DEFAULT 0,
  status text NOT NULL DEFAULT 'proposed' CHECK (status IN ('proposed','approved','in_progress','done','cancelled')),
  created_by_email text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  completed_at timestamptz
);

CREATE INDEX IF NOT EXISTS idx_etoa_r2354_engineer ON public.engineer_travel_optimization_actions_r2354(engineer_id);
CREATE INDEX IF NOT EXISTS idx_etoa_r2354_status ON public.engineer_travel_optimization_actions_r2354(status);
CREATE INDEX IF NOT EXISTS idx_etoa_r2354_city ON public.engineer_travel_optimization_actions_r2354(city);

ALTER TABLE public.engineer_travel_optimization_actions_r2354 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.engineer_travel_optimization_actions_r2354;
CREATE POLICY founder_all ON public.engineer_travel_optimization_actions_r2354
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- RPC 1: City-level travel vs billable breakdown
CREATE OR REPLACE FUNCTION public.engineer_travel_city_breakdown_r2354()
RETURNS TABLE (
  city text,
  region text,
  engineers_count bigint,
  total_shift_minutes bigint,
  total_travel_minutes bigint,
  total_billable_minutes bigint,
  total_idle_minutes bigint,
  travel_pct numeric,
  billable_pct numeric,
  total_distance_km numeric,
  total_revenue_rupees bigint
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    l.city,
    l.region,
    COUNT(DISTINCT l.engineer_id)::bigint AS engineers_count,
    SUM(l.total_shift_minutes)::bigint AS total_shift_minutes,
    SUM(l.travel_minutes)::bigint AS total_travel_minutes,
    SUM(l.billable_minutes)::bigint AS total_billable_minutes,
    SUM(l.idle_minutes)::bigint AS total_idle_minutes,
    ROUND((SUM(l.travel_minutes)::numeric / NULLIF(SUM(l.total_shift_minutes), 0)) * 100, 1) AS travel_pct,
    ROUND((SUM(l.billable_minutes)::numeric / NULLIF(SUM(l.total_shift_minutes), 0)) * 100, 1) AS billable_pct,
    SUM(l.distance_km)::numeric AS total_distance_km,
    SUM(l.revenue_generated_rupees)::bigint AS total_revenue_rupees
  FROM public.engineer_travel_time_logs_r2354 l
  WHERE l.log_date >= (CURRENT_DATE - INTERVAL '30 days')
  GROUP BY l.city, l.region
  ORDER BY travel_pct DESC NULLS LAST;
END;
$$;

REVOKE ALL ON FUNCTION public.engineer_travel_city_breakdown_r2354() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.engineer_travel_city_breakdown_r2354() TO authenticated;

-- RPC 2: Region-level rollup
CREATE OR REPLACE FUNCTION public.engineer_travel_region_rollup_r2354()
RETURNS TABLE (
  region text,
  engineers_count bigint,
  total_shift_minutes bigint,
  total_travel_minutes bigint,
  total_billable_minutes bigint,
  travel_pct numeric,
  billable_pct numeric,
  avg_distance_per_engineer_km numeric,
  total_revenue_rupees bigint
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    l.region,
    COUNT(DISTINCT l.engineer_id)::bigint,
    SUM(l.total_shift_minutes)::bigint,
    SUM(l.travel_minutes)::bigint,
    SUM(l.billable_minutes)::bigint,
    ROUND((SUM(l.travel_minutes)::numeric / NULLIF(SUM(l.total_shift_minutes), 0)) * 100, 1),
    ROUND((SUM(l.billable_minutes)::numeric / NULLIF(SUM(l.total_shift_minutes), 0)) * 100, 1),
    ROUND(SUM(l.distance_km)::numeric / NULLIF(COUNT(DISTINCT l.engineer_id), 0), 1),
    SUM(l.revenue_generated_rupees)::bigint
  FROM public.engineer_travel_time_logs_r2354 l
  WHERE l.log_date >= (CURRENT_DATE - INTERVAL '30 days')
  GROUP BY l.region
  ORDER BY l.region;
END;
$$;

REVOKE ALL ON FUNCTION public.engineer_travel_region_rollup_r2354() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.engineer_travel_region_rollup_r2354() TO authenticated;

-- RPC 3: Worst offenders (engineers with highest travel%)
CREATE OR REPLACE FUNCTION public.engineer_travel_worst_offenders_r2354()
RETURNS TABLE (
  engineer_id uuid,
  engineer_email text,
  city text,
  region text,
  days_logged bigint,
  total_shift_minutes bigint,
  travel_minutes bigint,
  billable_minutes bigint,
  travel_pct numeric,
  jobs_completed bigint
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    l.engineer_id,
    p.email AS engineer_email,
    l.city,
    l.region,
    COUNT(*)::bigint AS days_logged,
    SUM(l.total_shift_minutes)::bigint,
    SUM(l.travel_minutes)::bigint,
    SUM(l.billable_minutes)::bigint,
    ROUND((SUM(l.travel_minutes)::numeric / NULLIF(SUM(l.total_shift_minutes), 0)) * 100, 1) AS travel_pct,
    SUM(l.jobs_completed)::bigint
  FROM public.engineer_travel_time_logs_r2354 l
  JOIN public.profiles p ON p.id = l.engineer_id
  WHERE l.log_date >= (CURRENT_DATE - INTERVAL '30 days')
  GROUP BY l.engineer_id, p.email, l.city, l.region
  HAVING SUM(l.total_shift_minutes) > 0
  ORDER BY travel_pct DESC NULLS LAST
  LIMIT 25;
END;
$$;

REVOKE ALL ON FUNCTION public.engineer_travel_worst_offenders_r2354() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.engineer_travel_worst_offenders_r2354() TO authenticated;

-- RPC 4: Daily trend (last 30 days)
CREATE OR REPLACE FUNCTION public.engineer_travel_daily_trend_r2354()
RETURNS TABLE (
  log_date date,
  engineers_count bigint,
  total_travel_minutes bigint,
  total_billable_minutes bigint,
  travel_pct numeric,
  billable_pct numeric
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    l.log_date,
    COUNT(DISTINCT l.engineer_id)::bigint,
    SUM(l.travel_minutes)::bigint,
    SUM(l.billable_minutes)::bigint,
    ROUND((SUM(l.travel_minutes)::numeric / NULLIF(SUM(l.total_shift_minutes), 0)) * 100, 1),
    ROUND((SUM(l.billable_minutes)::numeric / NULLIF(SUM(l.total_shift_minutes), 0)) * 100, 1)
  FROM public.engineer_travel_time_logs_r2354 l
  WHERE l.log_date >= (CURRENT_DATE - INTERVAL '30 days')
  GROUP BY l.log_date
  ORDER BY l.log_date DESC;
END;
$$;

REVOKE ALL ON FUNCTION public.engineer_travel_daily_trend_r2354() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.engineer_travel_daily_trend_r2354() TO authenticated;

-- RPC 5: Top-performers (highest billable%)
CREATE OR REPLACE FUNCTION public.engineer_travel_top_performers_r2354()
RETURNS TABLE (
  engineer_id uuid,
  engineer_email text,
  city text,
  region text,
  days_logged bigint,
  billable_pct numeric,
  jobs_completed bigint,
  total_revenue_rupees bigint
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    l.engineer_id,
    p.email,
    l.city,
    l.region,
    COUNT(*)::bigint,
    ROUND((SUM(l.billable_minutes)::numeric / NULLIF(SUM(l.total_shift_minutes), 0)) * 100, 1),
    SUM(l.jobs_completed)::bigint,
    SUM(l.revenue_generated_rupees)::bigint
  FROM public.engineer_travel_time_logs_r2354 l
  JOIN public.profiles p ON p.id = l.engineer_id
  WHERE l.log_date >= (CURRENT_DATE - INTERVAL '30 days')
  GROUP BY l.engineer_id, p.email, l.city, l.region
  HAVING SUM(l.total_shift_minutes) > 0
  ORDER BY ROUND((SUM(l.billable_minutes)::numeric / NULLIF(SUM(l.total_shift_minutes), 0)) * 100, 1) DESC NULLS LAST
  LIMIT 25;
END;
$$;

REVOKE ALL ON FUNCTION public.engineer_travel_top_performers_r2354() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.engineer_travel_top_performers_r2354() TO authenticated;

-- RPC 6: Optimization actions list
CREATE OR REPLACE FUNCTION public.engineer_travel_optimization_actions_list_r2354()
RETURNS TABLE (
  id uuid,
  engineer_id uuid,
  city text,
  region text,
  action_type text,
  action_summary text,
  expected_minutes_saved integer,
  expected_rupees_saved integer,
  status text,
  created_by_email text,
  created_at timestamptz,
  completed_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.id, a.engineer_id, a.city, a.region, a.action_type, a.action_summary,
    a.expected_minutes_saved, a.expected_rupees_saved, a.status,
    a.created_by_email, a.created_at, a.completed_at
  FROM public.engineer_travel_optimization_actions_r2354 a
  ORDER BY a.created_at DESC
  LIMIT 100;
END;
$$;

REVOKE ALL ON FUNCTION public.engineer_travel_optimization_actions_list_r2354() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.engineer_travel_optimization_actions_list_r2354() TO authenticated;

-- RPC 7: Headline KPIs
CREATE OR REPLACE FUNCTION public.engineer_travel_headline_kpis_r2354()
RETURNS TABLE (
  engineers_tracked bigint,
  total_shift_hours numeric,
  total_travel_hours numeric,
  total_billable_hours numeric,
  travel_pct numeric,
  billable_pct numeric,
  total_distance_km numeric,
  total_fuel_cost_rupees bigint,
  total_revenue_rupees bigint,
  open_optimization_actions bigint
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    (SELECT COUNT(DISTINCT engineer_id) FROM public.engineer_travel_time_logs_r2354
       WHERE log_date >= (CURRENT_DATE - INTERVAL '30 days'))::bigint,
    ROUND(COALESCE((SELECT SUM(total_shift_minutes) FROM public.engineer_travel_time_logs_r2354
       WHERE log_date >= (CURRENT_DATE - INTERVAL '30 days')), 0)::numeric / 60, 1),
    ROUND(COALESCE((SELECT SUM(travel_minutes) FROM public.engineer_travel_time_logs_r2354
       WHERE log_date >= (CURRENT_DATE - INTERVAL '30 days')), 0)::numeric / 60, 1),
    ROUND(COALESCE((SELECT SUM(billable_minutes) FROM public.engineer_travel_time_logs_r2354
       WHERE log_date >= (CURRENT_DATE - INTERVAL '30 days')), 0)::numeric / 60, 1),
    ROUND(
      COALESCE((SELECT SUM(travel_minutes) FROM public.engineer_travel_time_logs_r2354
        WHERE log_date >= (CURRENT_DATE - INTERVAL '30 days')), 0)::numeric
      / NULLIF((SELECT SUM(total_shift_minutes) FROM public.engineer_travel_time_logs_r2354
        WHERE log_date >= (CURRENT_DATE - INTERVAL '30 days')), 0) * 100, 1),
    ROUND(
      COALESCE((SELECT SUM(billable_minutes) FROM public.engineer_travel_time_logs_r2354
        WHERE log_date >= (CURRENT_DATE - INTERVAL '30 days')), 0)::numeric
      / NULLIF((SELECT SUM(total_shift_minutes) FROM public.engineer_travel_time_logs_r2354
        WHERE log_date >= (CURRENT_DATE - INTERVAL '30 days')), 0) * 100, 1),
    COALESCE((SELECT SUM(distance_km) FROM public.engineer_travel_time_logs_r2354
       WHERE log_date >= (CURRENT_DATE - INTERVAL '30 days')), 0)::numeric,
    COALESCE((SELECT SUM(fuel_cost_rupees) FROM public.engineer_travel_time_logs_r2354
       WHERE log_date >= (CURRENT_DATE - INTERVAL '30 days')), 0)::bigint,
    COALESCE((SELECT SUM(revenue_generated_rupees) FROM public.engineer_travel_time_logs_r2354
       WHERE log_date >= (CURRENT_DATE - INTERVAL '30 days')), 0)::bigint,
    (SELECT COUNT(*) FROM public.engineer_travel_optimization_actions_r2354
       WHERE status IN ('proposed','approved','in_progress'))::bigint;
END;
$$;

REVOKE ALL ON FUNCTION public.engineer_travel_headline_kpis_r2354() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.engineer_travel_headline_kpis_r2354() TO authenticated;

COMMIT;
