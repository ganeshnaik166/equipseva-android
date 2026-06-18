BEGIN;
DROP FUNCTION IF EXISTS public.founder_jobs_by_day_30d();
CREATE OR REPLACE FUNCTION public.founder_jobs_by_day_30d()
RETURNS TABLE (
  day_ist     date,
  posted      bigint,
  completed   bigint,
  cancelled   bigint,
  bids        bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  WITH days AS (
    SELECT generate_series(
      (now() AT TIME ZONE 'Asia/Kolkata')::date - 29,
      (now() AT TIME ZONE 'Asia/Kolkata')::date,
      interval '1 day'
    )::date AS day_ist
  )
  SELECT
    d.day_ist,
    coalesce((SELECT count(*)::bigint FROM public.repair_jobs j
              WHERE (j.created_at AT TIME ZONE 'Asia/Kolkata')::date = d.day_ist), 0)              AS posted,
    coalesce((SELECT count(*)::bigint FROM public.repair_jobs j
              WHERE j.status = 'completed'
                AND (j.completed_at AT TIME ZONE 'Asia/Kolkata')::date = d.day_ist), 0)            AS completed,
    coalesce((SELECT count(*)::bigint FROM public.repair_jobs j
              WHERE j.status = 'cancelled'
                AND (j.created_at AT TIME ZONE 'Asia/Kolkata')::date = d.day_ist), 0)              AS cancelled,
    coalesce((SELECT count(*)::bigint FROM public.repair_job_bids b
              WHERE (b.created_at AT TIME ZONE 'Asia/Kolkata')::date = d.day_ist), 0)              AS bids
  FROM days d
  ORDER BY d.day_ist DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_jobs_by_day_30d() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_jobs_by_day_30d() TO authenticated;
COMMIT;
