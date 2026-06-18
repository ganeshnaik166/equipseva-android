BEGIN;
DROP FUNCTION IF EXISTS public.founder_jobs_cancellation_rate_by_week();
CREATE OR REPLACE FUNCTION public.founder_jobs_cancellation_rate_by_week()
RETURNS TABLE (
  week_start         date,
  posted             bigint,
  cancelled          bigint,
  cancellation_pct   numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  WITH weeks AS (
    SELECT generate_series(
      date_trunc('week', now() - interval '12 weeks')::date,
      date_trunc('week', now())::date,
      interval '1 week'
    )::date AS week_start
  )
  SELECT
    w.week_start,
    coalesce((SELECT count(*)::bigint FROM public.repair_jobs j
              WHERE date_trunc('week', (j.created_at AT TIME ZONE 'Asia/Kolkata'))::date = w.week_start), 0)              AS posted,
    coalesce((SELECT count(*)::bigint FROM public.repair_jobs j
              WHERE j.status = 'cancelled'
                AND date_trunc('week', (j.created_at AT TIME ZONE 'Asia/Kolkata'))::date = w.week_start), 0)              AS cancelled,
    CASE
      WHEN coalesce((SELECT count(*)::bigint FROM public.repair_jobs j
                     WHERE date_trunc('week', (j.created_at AT TIME ZONE 'Asia/Kolkata'))::date = w.week_start), 0) = 0
      THEN 0::numeric
      ELSE round(
        100.0 * coalesce((SELECT count(*)::numeric FROM public.repair_jobs j
                          WHERE j.status = 'cancelled'
                            AND date_trunc('week', (j.created_at AT TIME ZONE 'Asia/Kolkata'))::date = w.week_start), 0)
        / coalesce((SELECT count(*)::numeric FROM public.repair_jobs j
                    WHERE date_trunc('week', (j.created_at AT TIME ZONE 'Asia/Kolkata'))::date = w.week_start), 1),
        1)
    END                                                                                                                  AS cancellation_pct
  FROM weeks w
  ORDER BY w.week_start DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_jobs_cancellation_rate_by_week() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_jobs_cancellation_rate_by_week() TO authenticated;
COMMIT;
