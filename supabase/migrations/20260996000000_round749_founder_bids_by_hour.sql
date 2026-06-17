BEGIN;
DROP FUNCTION IF EXISTS public.founder_bids_by_hour();
CREATE OR REPLACE FUNCTION public.founder_bids_by_hour()
RETURNS TABLE (
  hour_ist int,
  bids     bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  WITH hours(h) AS (SELECT generate_series(0, 23))
  SELECT
    h.h,
    coalesce(
      (SELECT count(*)::bigint FROM public.repair_job_bids b
       WHERE b.created_at >= now() - interval '90 days'
         AND extract(hour FROM (b.created_at AT TIME ZONE 'Asia/Kolkata'))::int = h.h
      ), 0)::bigint
  FROM hours h
  ORDER BY h.h;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_bids_by_hour() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_bids_by_hour() TO authenticated;
COMMIT;
