BEGIN;
DROP FUNCTION IF EXISTS public.founder_jobs_by_week_13wk();
CREATE OR REPLACE FUNCTION public.founder_jobs_by_week_13wk()
RETURNS TABLE (
  week_start    date,
  posted        bigint,
  completed     bigint,
  cancelled     bigint,
  bids          bigint
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
              WHERE j.status = 'completed'
                AND date_trunc('week', (j.completed_at AT TIME ZONE 'Asia/Kolkata'))::date = w.week_start), 0)            AS completed,
    coalesce((SELECT count(*)::bigint FROM public.repair_jobs j
              WHERE j.status = 'cancelled'
                AND date_trunc('week', (j.created_at AT TIME ZONE 'Asia/Kolkata'))::date = w.week_start), 0)              AS cancelled,
    coalesce((SELECT count(*)::bigint FROM public.repair_job_bids b
              WHERE date_trunc('week', (b.created_at AT TIME ZONE 'Asia/Kolkata'))::date = w.week_start), 0)              AS bids
  FROM weeks w
  ORDER BY w.week_start DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_jobs_by_week_13wk() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_jobs_by_week_13wk() TO authenticated;
COMMIT;
