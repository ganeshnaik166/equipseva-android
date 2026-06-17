BEGIN;
DROP FUNCTION IF EXISTS public.founder_supervised_cumulative();
CREATE OR REPLACE FUNCTION public.founder_supervised_cumulative()
RETURNS TABLE (
  month_ist date,
  assigned  bigint,
  cum_assigned bigint,
  successful bigint,
  cum_successful bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  WITH months AS (
    SELECT generate_series(
      date_trunc('month', (now() AT TIME ZONE 'Asia/Kolkata')::date - interval '11 months'),
      date_trunc('month', (now() AT TIME ZONE 'Asia/Kolkata')::date),
      interval '1 month'
    )::date AS month_ist
  ),
  monthly AS (
    SELECT
      m.month_ist,
      coalesce((SELECT count(*)::bigint FROM public.supervised_job_assignments s
                WHERE date_trunc('month', (s.requested_at AT TIME ZONE 'Asia/Kolkata'))::date = m.month_ist), 0) AS a,
      coalesce((SELECT count(*)::bigint FROM public.supervised_job_assignments s
                WHERE s.status = 'completed_successful' AND s.completed_at IS NOT NULL
                  AND date_trunc('month', (s.completed_at AT TIME ZONE 'Asia/Kolkata'))::date = m.month_ist), 0) AS sc
    FROM months m
  )
  SELECT
    monthly.month_ist,
    monthly.a,
    sum(monthly.a) OVER (ORDER BY monthly.month_ist),
    monthly.sc,
    sum(monthly.sc) OVER (ORDER BY monthly.month_ist)
  FROM monthly
  ORDER BY monthly.month_ist DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_supervised_cumulative() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_supervised_cumulative() TO authenticated;
COMMIT;
