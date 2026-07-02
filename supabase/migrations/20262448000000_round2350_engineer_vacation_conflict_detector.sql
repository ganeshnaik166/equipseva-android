BEGIN;

-- Round 2350: Engineer scheduled-vacation conflict detector
-- Detects engineer leave overlapping with peak demand week or shared zone coverage gap

CREATE TABLE IF NOT EXISTS public.engineer_vacation_requests_r2350 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  zone_code text NOT NULL,
  starts_on date NOT NULL,
  ends_on date NOT NULL,
  reason text NOT NULL,
  status text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','approved','rejected','cancelled')),
  requested_at timestamptz NOT NULL DEFAULT now(),
  decided_at timestamptz,
  decided_by uuid REFERENCES public.profiles(id),
  override_note text,
  CHECK (ends_on >= starts_on)
);

CREATE INDEX IF NOT EXISTS idx_evr_r2350_engineer ON public.engineer_vacation_requests_r2350(engineer_user_id);
CREATE INDEX IF NOT EXISTS idx_evr_r2350_zone_dates ON public.engineer_vacation_requests_r2350(zone_code, starts_on, ends_on);
CREATE INDEX IF NOT EXISTS idx_evr_r2350_status ON public.engineer_vacation_requests_r2350(status);

ALTER TABLE public.engineer_vacation_requests_r2350 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.engineer_vacation_requests_r2350;
CREATE POLICY founder_all ON public.engineer_vacation_requests_r2350
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

CREATE TABLE IF NOT EXISTS public.zone_demand_forecast_r2350 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  zone_code text NOT NULL,
  week_starts_on date NOT NULL,
  expected_jobs integer NOT NULL DEFAULT 0,
  expected_amc_visits integer NOT NULL DEFAULT 0,
  is_peak_week boolean NOT NULL DEFAULT false,
  baseline_engineers_needed integer NOT NULL DEFAULT 1,
  computed_at timestamptz NOT NULL DEFAULT now(),
  notes text,
  UNIQUE (zone_code, week_starts_on)
);

CREATE INDEX IF NOT EXISTS idx_zdf_r2350_zone_week ON public.zone_demand_forecast_r2350(zone_code, week_starts_on);
CREATE INDEX IF NOT EXISTS idx_zdf_r2350_peak ON public.zone_demand_forecast_r2350(is_peak_week) WHERE is_peak_week;

ALTER TABLE public.zone_demand_forecast_r2350 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.zone_demand_forecast_r2350;
CREATE POLICY founder_all ON public.zone_demand_forecast_r2350
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- RPC 1: pending vacation requests
CREATE OR REPLACE FUNCTION public.r2350_pending_vacation_requests()
RETURNS TABLE (
  request_id uuid,
  engineer_email text,
  zone_code text,
  starts_on date,
  ends_on date,
  total_days integer,
  reason text,
  requested_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    r.id,
    p.email,
    r.zone_code,
    r.starts_on,
    r.ends_on,
    (r.ends_on - r.starts_on + 1)::integer,
    r.reason,
    r.requested_at
  FROM public.engineer_vacation_requests_r2350 r
  JOIN public.profiles p ON p.id = r.engineer_user_id
  WHERE r.status = 'pending'
  ORDER BY r.requested_at ASC;
END;
$$;

REVOKE ALL ON FUNCTION public.r2350_pending_vacation_requests() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r2350_pending_vacation_requests() TO authenticated;

-- RPC 2: peak-week conflicts
CREATE OR REPLACE FUNCTION public.r2350_peak_week_conflicts()
RETURNS TABLE (
  request_id uuid,
  engineer_email text,
  zone_code text,
  starts_on date,
  ends_on date,
  peak_week_starts_on date,
  expected_jobs integer,
  status text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    r.id,
    p.email,
    r.zone_code,
    r.starts_on,
    r.ends_on,
    f.week_starts_on,
    f.expected_jobs,
    r.status
  FROM public.engineer_vacation_requests_r2350 r
  JOIN public.profiles p ON p.id = r.engineer_user_id
  JOIN public.zone_demand_forecast_r2350 f
    ON f.zone_code = r.zone_code
   AND f.is_peak_week
   AND f.week_starts_on <= r.ends_on
   AND (f.week_starts_on + 6) >= r.starts_on
  WHERE r.status IN ('pending','approved')
  ORDER BY f.expected_jobs DESC, r.starts_on ASC;
END;
$$;

REVOKE ALL ON FUNCTION public.r2350_peak_week_conflicts() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r2350_peak_week_conflicts() TO authenticated;

-- RPC 3: zone coverage gaps
CREATE OR REPLACE FUNCTION public.r2350_zone_coverage_gaps()
RETURNS TABLE (
  zone_code text,
  week_starts_on date,
  baseline_engineers_needed integer,
  engineers_on_leave integer,
  gap_severity text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    f.zone_code,
    f.week_starts_on,
    f.baseline_engineers_needed,
    COUNT(r.id)::integer AS engineers_on_leave,
    CASE
      WHEN COUNT(r.id) >= f.baseline_engineers_needed THEN 'critical'
      WHEN COUNT(r.id) >= (f.baseline_engineers_needed - 1) THEN 'high'
      WHEN COUNT(r.id) > 0 THEN 'medium'
      ELSE 'ok'
    END
  FROM public.zone_demand_forecast_r2350 f
  LEFT JOIN public.engineer_vacation_requests_r2350 r
    ON r.zone_code = f.zone_code
   AND r.status = 'approved'
   AND r.starts_on <= (f.week_starts_on + 6)
   AND r.ends_on >= f.week_starts_on
  WHERE f.week_starts_on >= current_date - 7
  GROUP BY f.zone_code, f.week_starts_on, f.baseline_engineers_needed
  HAVING COUNT(r.id) > 0
  ORDER BY engineers_on_leave DESC, f.week_starts_on ASC;
END;
$$;

REVOKE ALL ON FUNCTION public.r2350_zone_coverage_gaps() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r2350_zone_coverage_gaps() TO authenticated;

-- RPC 4: engineer leave totals
CREATE OR REPLACE FUNCTION public.r2350_engineer_leave_totals()
RETURNS TABLE (
  engineer_email text,
  zone_code text,
  approved_days integer,
  pending_days integer,
  upcoming_starts_on date
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    p.email,
    r.zone_code,
    COALESCE(SUM(CASE WHEN r.status = 'approved' THEN (r.ends_on - r.starts_on + 1) END), 0)::integer,
    COALESCE(SUM(CASE WHEN r.status = 'pending' THEN (r.ends_on - r.starts_on + 1) END), 0)::integer,
    MIN(CASE WHEN r.starts_on >= current_date AND r.status IN ('approved','pending') THEN r.starts_on END)
  FROM public.engineer_vacation_requests_r2350 r
  JOIN public.profiles p ON p.id = r.engineer_user_id
  WHERE r.starts_on >= current_date - 30
  GROUP BY p.email, r.zone_code
  ORDER BY approved_days DESC;
END;
$$;

REVOKE ALL ON FUNCTION public.r2350_engineer_leave_totals() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r2350_engineer_leave_totals() TO authenticated;

-- RPC 5: peak weeks summary
CREATE OR REPLACE FUNCTION public.r2350_peak_weeks_summary()
RETURNS TABLE (
  zone_code text,
  week_starts_on date,
  expected_jobs integer,
  expected_amc_visits integer,
  baseline_engineers_needed integer,
  notes text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    f.zone_code,
    f.week_starts_on,
    f.expected_jobs,
    f.expected_amc_visits,
    f.baseline_engineers_needed,
    f.notes
  FROM public.zone_demand_forecast_r2350 f
  WHERE f.is_peak_week
    AND f.week_starts_on >= current_date - 7
  ORDER BY f.week_starts_on ASC, f.expected_jobs DESC;
END;
$$;

REVOKE ALL ON FUNCTION public.r2350_peak_weeks_summary() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r2350_peak_weeks_summary() TO authenticated;

-- RPC 6: decisions log
CREATE OR REPLACE FUNCTION public.r2350_recent_decisions()
RETURNS TABLE (
  request_id uuid,
  engineer_email text,
  zone_code text,
  starts_on date,
  ends_on date,
  status text,
  decided_at timestamptz,
  decided_by_email text,
  override_note text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    r.id,
    pe.email,
    r.zone_code,
    r.starts_on,
    r.ends_on,
    r.status,
    r.decided_at,
    pd.email,
    r.override_note
  FROM public.engineer_vacation_requests_r2350 r
  JOIN public.profiles pe ON pe.id = r.engineer_user_id
  LEFT JOIN public.profiles pd ON pd.id = r.decided_by
  WHERE r.decided_at IS NOT NULL
  ORDER BY r.decided_at DESC
  LIMIT 50;
END;
$$;

REVOKE ALL ON FUNCTION public.r2350_recent_decisions() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r2350_recent_decisions() TO authenticated;

-- RPC 7: dashboard counters
CREATE OR REPLACE FUNCTION public.r2350_dashboard_counters()
RETURNS TABLE (
  pending_requests integer,
  approved_upcoming integer,
  peak_week_conflicts integer,
  critical_gaps integer,
  total_engineers_on_leave_this_week integer
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    (SELECT COUNT(*)::integer FROM public.engineer_vacation_requests_r2350 WHERE status = 'pending'),
    (SELECT COUNT(*)::integer FROM public.engineer_vacation_requests_r2350 WHERE status = 'approved' AND starts_on >= current_date),
    (SELECT COUNT(*)::integer
       FROM public.engineer_vacation_requests_r2350 r
       JOIN public.zone_demand_forecast_r2350 f
         ON f.zone_code = r.zone_code
        AND f.is_peak_week
        AND f.week_starts_on <= r.ends_on
        AND (f.week_starts_on + 6) >= r.starts_on
      WHERE r.status IN ('pending','approved')),
    (SELECT COUNT(*)::integer FROM (
       SELECT f.zone_code, f.week_starts_on
       FROM public.zone_demand_forecast_r2350 f
       JOIN public.engineer_vacation_requests_r2350 r
         ON r.zone_code = f.zone_code
        AND r.status = 'approved'
        AND r.starts_on <= (f.week_starts_on + 6)
        AND r.ends_on >= f.week_starts_on
       WHERE f.week_starts_on >= current_date - 7
       GROUP BY f.zone_code, f.week_starts_on, f.baseline_engineers_needed
       HAVING COUNT(r.id) >= f.baseline_engineers_needed
     ) g),
    (SELECT COUNT(*)::integer
       FROM public.engineer_vacation_requests_r2350
      WHERE status = 'approved'
        AND starts_on <= current_date + 6
        AND ends_on >= current_date);
END;
$$;

REVOKE ALL ON FUNCTION public.r2350_dashboard_counters() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r2350_dashboard_counters() TO authenticated;

COMMIT;
