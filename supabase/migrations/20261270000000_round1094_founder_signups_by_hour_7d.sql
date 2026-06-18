BEGIN;
DROP FUNCTION IF EXISTS public.founder_signups_by_hour_7d();
CREATE OR REPLACE FUNCTION public.founder_signups_by_hour_7d()
RETURNS TABLE (
  hour_ist            int,
  engineer_signups    bigint,
  hospital_signups    bigint,
  other_signups       bigint,
  total               bigint
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
    coalesce((SELECT count(*)::bigint FROM public.profiles p
              WHERE p.role = 'engineer'
                AND p.created_at >= now() - interval '7 days'
                AND extract(hour FROM (p.created_at AT TIME ZONE 'Asia/Kolkata'))::int = h.hour_ist), 0)             AS engineer_signups,
    coalesce((SELECT count(*)::bigint FROM public.profiles p
              WHERE p.role = 'hospital'
                AND p.created_at >= now() - interval '7 days'
                AND extract(hour FROM (p.created_at AT TIME ZONE 'Asia/Kolkata'))::int = h.hour_ist), 0)             AS hospital_signups,
    coalesce((SELECT count(*)::bigint FROM public.profiles p
              WHERE p.role NOT IN ('engineer','hospital')
                AND p.created_at >= now() - interval '7 days'
                AND extract(hour FROM (p.created_at AT TIME ZONE 'Asia/Kolkata'))::int = h.hour_ist), 0)             AS other_signups,
    coalesce((SELECT count(*)::bigint FROM public.profiles p
              WHERE p.created_at >= now() - interval '7 days'
                AND extract(hour FROM (p.created_at AT TIME ZONE 'Asia/Kolkata'))::int = h.hour_ist), 0)             AS total
  FROM hours h
  ORDER BY h.hour_ist;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_signups_by_hour_7d() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_signups_by_hour_7d() TO authenticated;
COMMIT;
