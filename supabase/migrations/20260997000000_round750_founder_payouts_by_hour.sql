BEGIN;
DROP FUNCTION IF EXISTS public.founder_payouts_by_hour();
CREATE OR REPLACE FUNCTION public.founder_payouts_by_hour()
RETURNS TABLE (
  hour_ist int,
  paid     bigint,
  failed   bigint
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
      (SELECT count(*)::bigint FROM public.engineer_payouts p
       WHERE p.queued_at >= now() - interval '90 days'
         AND p.status = 'processed'
         AND extract(hour FROM (p.queued_at AT TIME ZONE 'Asia/Kolkata'))::int = h.h
      ), 0)::bigint,
    coalesce(
      (SELECT count(*)::bigint FROM public.engineer_payouts p
       WHERE p.queued_at >= now() - interval '90 days'
         AND p.status = 'failed'
         AND extract(hour FROM (p.queued_at AT TIME ZONE 'Asia/Kolkata'))::int = h.h
      ), 0)::bigint
  FROM hours h
  ORDER BY h.h;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_payouts_by_hour() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_payouts_by_hour() TO authenticated;
COMMIT;
