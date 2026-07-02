-- Round 2426 — Engineer Vehicle Fuel Log
-- Track per-engineer vehicle trips, km, fuel L, INR/km, and zone-benchmark outliers.

BEGIN;

-- ============================================================================
-- TABLE: engineer_vehicle_trips_r2426
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.engineer_vehicle_trips_r2426 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at timestamptz NOT NULL DEFAULT now(),
  engineer_user_id uuid REFERENCES public.engineers(id) ON DELETE SET NULL,
  vehicle_label text NOT NULL,
  trip_started_at timestamptz NOT NULL,
  trip_ended_at timestamptz NOT NULL,
  start_km integer NOT NULL CHECK (start_km >= 0),
  end_km integer NOT NULL CHECK (end_km >= 0),
  km_driven integer NOT NULL CHECK (km_driven >= 0),
  fuel_litres numeric NOT NULL DEFAULT 0 CHECK (fuel_litres >= 0),
  fuel_cost_rupees integer NOT NULL DEFAULT 0 CHECK (fuel_cost_rupees >= 0),
  zone_label text NOT NULL,
  jobs_count integer NOT NULL DEFAULT 0 CHECK (jobs_count >= 0),
  cost_per_km numeric NOT NULL DEFAULT 0 CHECK (cost_per_km >= 0),
  notes text,
  CHECK (trip_ended_at >= trip_started_at),
  CHECK (end_km >= start_km)
);

ALTER TABLE public.engineer_vehicle_trips_r2426 ENABLE ROW LEVEL SECURITY;

CREATE POLICY founder_all ON public.engineer_vehicle_trips_r2426
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- ============================================================================
-- TABLE: vehicle_outlier_flags_r2426
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.vehicle_outlier_flags_r2426 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at timestamptz NOT NULL DEFAULT now(),
  engineer_user_id uuid REFERENCES public.engineers(id) ON DELETE SET NULL,
  vehicle_label text NOT NULL,
  flag_kind text NOT NULL CHECK (flag_kind IN ('high_km_per_job','fuel_burn_high','zone_benchmark_breach','no_job_km')),
  flag_period_start date NOT NULL,
  flag_period_end date NOT NULL,
  observed_value numeric NOT NULL DEFAULT 0,
  benchmark_value numeric NOT NULL DEFAULT 0,
  delta_pct numeric NOT NULL DEFAULT 0,
  severity text NOT NULL DEFAULT 'low' CHECK (severity IN ('low','medium','high','critical')),
  status text NOT NULL DEFAULT 'open' CHECK (status IN ('open','under_review','resolved','dropped')),
  action_taken text,
  closed_at timestamptz,
  closed_by_email text,
  notes text,
  CHECK (flag_period_end >= flag_period_start)
);

ALTER TABLE public.vehicle_outlier_flags_r2426 ENABLE ROW LEVEL SECURITY;

CREATE POLICY founder_all ON public.vehicle_outlier_flags_r2426
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- ============================================================================
-- RPC: list_trips_r2426
-- ============================================================================
CREATE OR REPLACE FUNCTION public.list_trips_r2426()
RETURNS TABLE (
  id uuid,
  engineer_user_id uuid,
  vehicle_label text,
  trip_started_at timestamptz,
  trip_ended_at timestamptz,
  start_km integer,
  end_km integer,
  km_driven integer,
  fuel_litres numeric,
  fuel_cost_rupees integer,
  zone_label text,
  jobs_count integer,
  cost_per_km numeric,
  notes text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT t.id, t.engineer_user_id, t.vehicle_label, t.trip_started_at, t.trip_ended_at,
           t.start_km, t.end_km, t.km_driven, t.fuel_litres, t.fuel_cost_rupees,
           t.zone_label, t.jobs_count, t.cost_per_km, t.notes
      FROM public.engineer_vehicle_trips_r2426 t
      ORDER BY t.trip_started_at DESC, t.created_at DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_trips_r2426() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_trips_r2426() TO authenticated;

-- ============================================================================
-- RPC: list_outliers_r2426
-- ============================================================================
CREATE OR REPLACE FUNCTION public.list_outliers_r2426()
RETURNS TABLE (
  id uuid,
  engineer_user_id uuid,
  vehicle_label text,
  flag_kind text,
  flag_period_start date,
  flag_period_end date,
  observed_value numeric,
  benchmark_value numeric,
  delta_pct numeric,
  severity text,
  status text,
  action_taken text,
  closed_at timestamptz,
  closed_by_email text,
  notes text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT f.id, f.engineer_user_id, f.vehicle_label, f.flag_kind,
           f.flag_period_start, f.flag_period_end, f.observed_value,
           f.benchmark_value, f.delta_pct, f.severity, f.status,
           f.action_taken, f.closed_at, f.closed_by_email, f.notes
      FROM public.vehicle_outlier_flags_r2426 f
      ORDER BY f.flag_period_end DESC, f.created_at DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_outliers_r2426() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_outliers_r2426() TO authenticated;

-- ============================================================================
-- RPC: top_cost_engineers_r2426
-- ============================================================================
CREATE OR REPLACE FUNCTION public.top_cost_engineers_r2426()
RETURNS TABLE (
  engineer_user_id uuid,
  trip_count bigint,
  total_km bigint,
  total_litres numeric,
  total_fuel_cost_rupees bigint,
  avg_cost_per_km numeric,
  total_jobs bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT t.engineer_user_id,
           COUNT(*)::bigint AS trip_count,
           COALESCE(SUM(t.km_driven),0)::bigint AS total_km,
           COALESCE(SUM(t.fuel_litres),0)::numeric AS total_litres,
           COALESCE(SUM(t.fuel_cost_rupees),0)::bigint AS total_fuel_cost_rupees,
           CASE WHEN COALESCE(SUM(t.km_driven),0) > 0
                THEN ROUND(SUM(t.fuel_cost_rupees)::numeric / SUM(t.km_driven)::numeric, 2)
                ELSE 0::numeric END AS avg_cost_per_km,
           COALESCE(SUM(t.jobs_count),0)::bigint AS total_jobs
      FROM public.engineer_vehicle_trips_r2426 t
     GROUP BY t.engineer_user_id
     ORDER BY total_fuel_cost_rupees DESC
     LIMIT 10;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.top_cost_engineers_r2426() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.top_cost_engineers_r2426() TO authenticated;

-- ============================================================================
-- RPC: zone_benchmark_summary_r2426
-- ============================================================================
CREATE OR REPLACE FUNCTION public.zone_benchmark_summary_r2426()
RETURNS TABLE (
  zone_label text,
  trip_count bigint,
  total_km bigint,
  total_litres numeric,
  total_fuel_cost_rupees bigint,
  avg_cost_per_km numeric,
  total_jobs bigint,
  km_per_job numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT t.zone_label,
           COUNT(*)::bigint AS trip_count,
           COALESCE(SUM(t.km_driven),0)::bigint AS total_km,
           COALESCE(SUM(t.fuel_litres),0)::numeric AS total_litres,
           COALESCE(SUM(t.fuel_cost_rupees),0)::bigint AS total_fuel_cost_rupees,
           CASE WHEN COALESCE(SUM(t.km_driven),0) > 0
                THEN ROUND(SUM(t.fuel_cost_rupees)::numeric / SUM(t.km_driven)::numeric, 2)
                ELSE 0::numeric END AS avg_cost_per_km,
           COALESCE(SUM(t.jobs_count),0)::bigint AS total_jobs,
           CASE WHEN COALESCE(SUM(t.jobs_count),0) > 0
                THEN ROUND(SUM(t.km_driven)::numeric / SUM(t.jobs_count)::numeric, 2)
                ELSE 0::numeric END AS km_per_job
      FROM public.engineer_vehicle_trips_r2426 t
     GROUP BY t.zone_label
     ORDER BY total_fuel_cost_rupees DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.zone_benchmark_summary_r2426() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.zone_benchmark_summary_r2426() TO authenticated;

-- ============================================================================
-- RPC: weekly_fuel_trend_r2426
-- ============================================================================
CREATE OR REPLACE FUNCTION public.weekly_fuel_trend_r2426()
RETURNS TABLE (
  week_start date,
  trip_count bigint,
  total_km bigint,
  total_litres numeric,
  total_fuel_cost_rupees bigint,
  avg_cost_per_km numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT date_trunc('week', t.trip_started_at)::date AS week_start,
           COUNT(*)::bigint AS trip_count,
           COALESCE(SUM(t.km_driven),0)::bigint AS total_km,
           COALESCE(SUM(t.fuel_litres),0)::numeric AS total_litres,
           COALESCE(SUM(t.fuel_cost_rupees),0)::bigint AS total_fuel_cost_rupees,
           CASE WHEN COALESCE(SUM(t.km_driven),0) > 0
                THEN ROUND(SUM(t.fuel_cost_rupees)::numeric / SUM(t.km_driven)::numeric, 2)
                ELSE 0::numeric END AS avg_cost_per_km
      FROM public.engineer_vehicle_trips_r2426 t
     GROUP BY date_trunc('week', t.trip_started_at)::date
     ORDER BY week_start DESC
     LIMIT 12;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.weekly_fuel_trend_r2426() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.weekly_fuel_trend_r2426() TO authenticated;

-- ============================================================================
-- RPC: vehicle_utilization_r2426
-- ============================================================================
CREATE OR REPLACE FUNCTION public.vehicle_utilization_r2426()
RETURNS TABLE (
  vehicle_label text,
  trip_count bigint,
  total_km bigint,
  total_litres numeric,
  total_fuel_cost_rupees bigint,
  total_jobs bigint,
  km_per_job numeric,
  avg_cost_per_km numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT t.vehicle_label,
           COUNT(*)::bigint AS trip_count,
           COALESCE(SUM(t.km_driven),0)::bigint AS total_km,
           COALESCE(SUM(t.fuel_litres),0)::numeric AS total_litres,
           COALESCE(SUM(t.fuel_cost_rupees),0)::bigint AS total_fuel_cost_rupees,
           COALESCE(SUM(t.jobs_count),0)::bigint AS total_jobs,
           CASE WHEN COALESCE(SUM(t.jobs_count),0) > 0
                THEN ROUND(SUM(t.km_driven)::numeric / SUM(t.jobs_count)::numeric, 2)
                ELSE 0::numeric END AS km_per_job,
           CASE WHEN COALESCE(SUM(t.km_driven),0) > 0
                THEN ROUND(SUM(t.fuel_cost_rupees)::numeric / SUM(t.km_driven)::numeric, 2)
                ELSE 0::numeric END AS avg_cost_per_km
      FROM public.engineer_vehicle_trips_r2426 t
     GROUP BY t.vehicle_label
     ORDER BY total_km DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.vehicle_utilization_r2426() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.vehicle_utilization_r2426() TO authenticated;

-- ============================================================================
-- RPC: top_outliers_open_r2426
-- ============================================================================
CREATE OR REPLACE FUNCTION public.top_outliers_open_r2426()
RETURNS TABLE (
  id uuid,
  engineer_user_id uuid,
  vehicle_label text,
  flag_kind text,
  flag_period_start date,
  flag_period_end date,
  observed_value numeric,
  benchmark_value numeric,
  delta_pct numeric,
  severity text,
  status text,
  notes text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT f.id, f.engineer_user_id, f.vehicle_label, f.flag_kind,
           f.flag_period_start, f.flag_period_end, f.observed_value,
           f.benchmark_value, f.delta_pct, f.severity, f.status, f.notes
      FROM public.vehicle_outlier_flags_r2426 f
     WHERE f.status IN ('open','under_review')
     ORDER BY CASE f.severity
                WHEN 'critical' THEN 1
                WHEN 'high' THEN 2
                WHEN 'medium' THEN 3
                WHEN 'low' THEN 4
                ELSE 5 END,
              f.delta_pct DESC,
              f.flag_period_end DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.top_outliers_open_r2426() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.top_outliers_open_r2426() TO authenticated;

-- ============================================================================
-- SEED DATA
-- ============================================================================
INSERT INTO public.engineer_vehicle_trips_r2426 (vehicle_label, trip_started_at, trip_ended_at, start_km, end_km, km_driven, fuel_litres, fuel_cost_rupees, zone_label, jobs_count, cost_per_km, notes)
VALUES
  ('TS09-AB-1234', now() - interval '6 days', now() - interval '6 days' + interval '8 hours', 12000, 12085, 85, 6.50, 715, 'Hyderabad-Central', 4, 8.41, 'Mon route Banjara + KPHB'),
  ('TS09-AB-1234', now() - interval '5 days', now() - interval '5 days' + interval '9 hours', 12085, 12190, 105, 8.20, 902, 'Hyderabad-North', 3, 8.59, 'Tue route Secunderabad'),
  ('TS09-CD-5678', now() - interval '4 days', now() - interval '4 days' + interval '7 hours', 8400, 8460, 60, 5.10, 561, 'Hyderabad-South', 5, 9.35, 'Wed route LB Nagar'),
  ('TS09-CD-5678', now() - interval '3 days', now() - interval '3 days' + interval '10 hours', 8460, 8625, 165, 13.40, 1474, 'Hyderabad-Outskirts', 2, 8.93, 'Thu route Shamshabad airport-zone'),
  ('TS09-EF-9012', now() - interval '2 days', now() - interval '2 days' + interval '6 hours', 5200, 5288, 88, 7.80, 858, 'Hyderabad-Central', 3, 9.75, 'Fri route Hi-Tech City');

INSERT INTO public.vehicle_outlier_flags_r2426 (vehicle_label, flag_kind, flag_period_start, flag_period_end, observed_value, benchmark_value, delta_pct, severity, status, action_taken, closed_at, closed_by_email, notes)
VALUES
  ('TS09-CD-5678', 'high_km_per_job', (now() - interval '4 days')::date, (now() - interval '3 days')::date, 82.50, 35.00, 135.71, 'high', 'open', null, null, null, 'Outskirts trip burned 82km/job vs benchmark 35'),
  ('TS09-EF-9012', 'fuel_burn_high', (now() - interval '3 days')::date, (now() - interval '2 days')::date, 9.75, 7.50, 30.00, 'medium', 'under_review', 'Engineer briefed; route audit pending', null, null, 'Cost/km 9.75 vs zone median 7.50'),
  ('TS09-AB-1234', 'zone_benchmark_breach', (now() - interval '6 days')::date, (now() - interval '5 days')::date, 8.59, 8.00, 7.38, 'low', 'resolved', 'Within tolerance; ack', now() - interval '4 days', 'founder@equipseva.in', 'Marginal breach Hyderabad-North'),
  ('TS09-CD-5678', 'no_job_km', (now() - interval '3 days')::date, (now() - interval '3 days')::date, 165.00, 100.00, 65.00, 'critical', 'open', null, null, null, '165km with only 2 jobs — verify deadhead');

