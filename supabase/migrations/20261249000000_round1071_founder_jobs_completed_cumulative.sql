BEGIN;
DROP FUNCTION IF EXISTS public.founder_jobs_completed_cumulative();
CREATE OR REPLACE FUNCTION public.founder_jobs_completed_cumulative()
RETURNS TABLE (
  month_ist        date,
  monthly_done     bigint,
  cumulative_done  bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  WITH months AS (
    SELECT generate_series(
      date_trunc('month', now() - interval '11 months')::date,
      date_trunc('month', now())::date,
      interval '1 month'
    )::date AS month_ist
  ),
  monthly AS (
    SELECT
      m.month_ist,
      coalesce((SELECT count(*)::bigint FROM public.repair_jobs j
                WHERE j.status = 'completed'
                  AND date_trunc('month', (j.completed_at AT TIME ZONE 'Asia/Kolkata'))::date = m.month_ist), 0) AS monthly_done
    FROM months m
  )
  SELECT
    m.month_ist,
    m.monthly_done,
    sum(m.monthly_done) OVER (ORDER BY m.month_ist ASC ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW)::bigint
                                                                    AS cumulative_done
  FROM monthly m
  ORDER BY m.month_ist DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_jobs_completed_cumulative() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_jobs_completed_cumulative() TO authenticated;
COMMIT;
