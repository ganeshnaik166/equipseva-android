BEGIN;
DROP FUNCTION IF EXISTS public.founder_code_red_volume_trend();
CREATE OR REPLACE FUNCTION public.founder_code_red_volume_trend()
RETURNS TABLE (
  day_ist       date,
  opened        bigint,
  accepted      bigint,
  resolved      bigint,
  timed_out     bigint
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
      (SELECT count(*)::bigint FROM public.code_red_requests r
       WHERE (r.created_at AT TIME ZONE 'Asia/Kolkata')::date = d.day_ist
      ), 0)::bigint,
    coalesce(
      (SELECT count(*)::bigint FROM public.code_red_requests r
       WHERE r.status IN ('engineer_accepted','resolved')
         AND (r.created_at AT TIME ZONE 'Asia/Kolkata')::date = d.day_ist
      ), 0)::bigint,
    coalesce(
      (SELECT count(*)::bigint FROM public.code_red_requests r
       WHERE r.status = 'resolved'
         AND (r.created_at AT TIME ZONE 'Asia/Kolkata')::date = d.day_ist
      ), 0)::bigint,
    coalesce(
      (SELECT count(*)::bigint FROM public.code_red_requests r
       WHERE r.status = 'timed_out'
         AND (r.created_at AT TIME ZONE 'Asia/Kolkata')::date = d.day_ist
      ), 0)::bigint
  FROM days d
  ORDER BY d.day_ist DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_code_red_volume_trend() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_code_red_volume_trend() TO authenticated;
COMMIT;
