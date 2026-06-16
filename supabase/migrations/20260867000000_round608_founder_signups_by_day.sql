-- =====================================================================
-- Round 608 — Founder signups-by-day funnel view
-- =====================================================================
--
-- "Are signups trending up?" needs a 30-day daily series, not the
-- single hero KPI on /dashboard. r608 ships the time-series RPC. The
-- existing /funnel page extends naturally.

BEGIN;

DROP FUNCTION IF EXISTS public.founder_signups_by_day(int);

CREATE OR REPLACE FUNCTION public.founder_signups_by_day(p_days int DEFAULT 30)
RETURNS TABLE (
  day_ist        date,
  signups        bigint,
  hospitals      bigint,
  engineers      bigint
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_days int := least(greatest(coalesce(p_days, 30), 1), 90);
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE = '42501';
  END IF;

  RETURN QUERY
  WITH days AS (
    SELECT generate_series(
      (current_date - (v_days - 1))::date,
      current_date::date,
      interval '1 day'
    )::date AS d
  ),
  signups AS (
    -- IST day for the createdAt timestamp
    SELECT
      (u.created_at AT TIME ZONE 'Asia/Kolkata')::date AS d,
      coalesce(lower(p.role::text), 'unknown')          AS role
    FROM auth.users u
    LEFT JOIN public.profiles p ON p.id = u.id
    WHERE u.created_at >= (current_date - (v_days - 1))
  )
  SELECT
    d.d                                                   AS day_ist,
    count(s.d)::bigint                                    AS signups,
    count(*) FILTER (WHERE s.role = 'hospital')::bigint   AS hospitals,
    count(*) FILTER (WHERE s.role = 'engineer')::bigint   AS engineers
  FROM days d
  LEFT JOIN signups s ON s.d = d.d
  GROUP BY d.d
  ORDER BY d.d ASC;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_signups_by_day(int) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_signups_by_day(int) TO authenticated;

COMMIT;
