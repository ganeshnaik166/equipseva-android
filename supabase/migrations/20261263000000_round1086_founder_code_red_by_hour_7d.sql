BEGIN;
DROP FUNCTION IF EXISTS public.founder_code_red_by_hour_7d();
CREATE OR REPLACE FUNCTION public.founder_code_red_by_hour_7d()
RETURNS TABLE (
  hour_ist     int,
  total        bigint,
  resolved     bigint,
  timed_out    bigint
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
    coalesce((SELECT count(*)::bigint FROM public.code_red_requests r
              WHERE r.created_at >= now() - interval '7 days'
                AND extract(hour FROM (r.created_at AT TIME ZONE 'Asia/Kolkata'))::int = h.hour_ist), 0)             AS total,
    coalesce((SELECT count(*)::bigint FROM public.code_red_requests r
              WHERE r.status = 'resolved'
                AND r.created_at >= now() - interval '7 days'
                AND extract(hour FROM (r.created_at AT TIME ZONE 'Asia/Kolkata'))::int = h.hour_ist), 0)             AS resolved,
    coalesce((SELECT count(*)::bigint FROM public.code_red_requests r
              WHERE r.status = 'timed_out'
                AND r.created_at >= now() - interval '7 days'
                AND extract(hour FROM (r.created_at AT TIME ZONE 'Asia/Kolkata'))::int = h.hour_ist), 0)             AS timed_out
  FROM hours h
  ORDER BY h.hour_ist;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_code_red_by_hour_7d() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_code_red_by_hour_7d() TO authenticated;
COMMIT;
