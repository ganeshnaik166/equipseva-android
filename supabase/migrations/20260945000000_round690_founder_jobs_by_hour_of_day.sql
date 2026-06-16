BEGIN;
DROP FUNCTION IF EXISTS public.founder_jobs_by_hour_of_day();
CREATE OR REPLACE FUNCTION public.founder_jobs_by_hour_of_day()
RETURNS TABLE (
  hour_ist  int,
  jobs      bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  WITH hours(h) AS (
    SELECT generate_series(0, 23)
  )
  SELECT
    h.h,
    coalesce(
      (SELECT count(*)::bigint FROM public.repair_jobs rj
       WHERE rj.created_at >= now() - interval '30 days'
         AND extract(hour FROM (rj.created_at AT TIME ZONE 'Asia/Kolkata'))::int = h.h
      ), 0)::bigint
  FROM hours h
  ORDER BY h.h;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_jobs_by_hour_of_day() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_jobs_by_hour_of_day() TO authenticated;
COMMIT;
