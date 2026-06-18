BEGIN;
DROP FUNCTION IF EXISTS public.founder_payouts_by_hour_7d();
CREATE OR REPLACE FUNCTION public.founder_payouts_by_hour_7d()
RETURNS TABLE (
  hour_ist        int,
  queued          bigint,
  processed       bigint,
  failed          bigint,
  total_inr       numeric
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
    coalesce((SELECT count(*)::bigint FROM public.engineer_payouts p
              WHERE p.queued_at >= now() - interval '7 days'
                AND extract(hour FROM (p.queued_at AT TIME ZONE 'Asia/Kolkata'))::int = h.hour_ist), 0)              AS queued,
    coalesce((SELECT count(*)::bigint FROM public.engineer_payouts p
              WHERE p.status IN ('processed','paid')
                AND p.queued_at >= now() - interval '7 days'
                AND extract(hour FROM (p.queued_at AT TIME ZONE 'Asia/Kolkata'))::int = h.hour_ist), 0)              AS processed,
    coalesce((SELECT count(*)::bigint FROM public.engineer_payouts p
              WHERE p.status = 'failed'
                AND p.queued_at >= now() - interval '7 days'
                AND extract(hour FROM (p.queued_at AT TIME ZONE 'Asia/Kolkata'))::int = h.hour_ist), 0)              AS failed,
    coalesce((SELECT sum(p.amount_inr)::numeric FROM public.engineer_payouts p
              WHERE p.status IN ('processed','paid')
                AND p.queued_at >= now() - interval '7 days'
                AND extract(hour FROM (p.queued_at AT TIME ZONE 'Asia/Kolkata'))::int = h.hour_ist), 0)              AS total_inr
  FROM hours h
  ORDER BY h.hour_ist;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_payouts_by_hour_7d() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_payouts_by_hour_7d() TO authenticated;
COMMIT;
