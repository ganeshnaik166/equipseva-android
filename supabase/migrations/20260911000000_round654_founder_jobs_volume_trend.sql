BEGIN;
DROP FUNCTION IF EXISTS public.founder_jobs_volume_trend();
CREATE OR REPLACE FUNCTION public.founder_jobs_volume_trend()
RETURNS TABLE (
  day_ist        date,
  jobs_posted    bigint,
  jobs_completed bigint,
  gross_rupees   numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  WITH days AS (
    SELECT generate_series(
      (now() AT TIME ZONE 'Asia/Kolkata')::date - 13,
      (now() AT TIME ZONE 'Asia/Kolkata')::date,
      interval '1 day'
    )::date AS day_ist
  )
  SELECT
    d.day_ist,
    coalesce(
      (SELECT count(*)::bigint FROM public.repair_jobs rj
       WHERE (rj.created_at AT TIME ZONE 'Asia/Kolkata')::date = d.day_ist
      ), 0)::bigint AS jobs_posted,
    coalesce(
      (SELECT count(*)::bigint FROM public.repair_jobs rj
       WHERE rj.status = 'completed'
         AND (rj.completed_at AT TIME ZONE 'Asia/Kolkata')::date = d.day_ist
      ), 0)::bigint AS jobs_completed,
    coalesce(
      (SELECT sum(rj.contracted_amount_rupees)::numeric FROM public.repair_jobs rj
       WHERE rj.status = 'completed'
         AND (rj.completed_at AT TIME ZONE 'Asia/Kolkata')::date = d.day_ist
      ), 0)::numeric AS gross_rupees
  FROM days d
  ORDER BY d.day_ist DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_jobs_volume_trend() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_jobs_volume_trend() TO authenticated;
COMMIT;
