BEGIN;
DROP FUNCTION IF EXISTS public.founder_jobs_by_hour_7d();
CREATE OR REPLACE FUNCTION public.founder_jobs_by_hour_7d()
RETURNS TABLE (
  hour_ist           int,
  jobs_posted        bigint,
  bids_placed        bigint,
  jobs_completed     bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  WITH hours AS (
    SELECT generate_series(0, 23) AS hour_ist
  )
  SELECT
    h.hour_ist,
    coalesce((SELECT count(*)::bigint FROM public.repair_jobs j
              WHERE j.created_at >= now() - interval '7 days'
                AND extract(hour FROM (j.created_at AT TIME ZONE 'Asia/Kolkata'))::int = h.hour_ist), 0)
                                                                                AS jobs_posted,
    coalesce((SELECT count(*)::bigint FROM public.repair_job_bids b
              WHERE b.created_at >= now() - interval '7 days'
                AND extract(hour FROM (b.created_at AT TIME ZONE 'Asia/Kolkata'))::int = h.hour_ist), 0)
                                                                                AS bids_placed,
    coalesce((SELECT count(*)::bigint FROM public.repair_jobs j
              WHERE j.status = 'completed'
                AND j.completed_at >= now() - interval '7 days'
                AND extract(hour FROM (j.completed_at AT TIME ZONE 'Asia/Kolkata'))::int = h.hour_ist), 0)
                                                                                AS jobs_completed
  FROM hours h
  ORDER BY h.hour_ist;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_jobs_by_hour_7d() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_jobs_by_hour_7d() TO authenticated;
COMMIT;
