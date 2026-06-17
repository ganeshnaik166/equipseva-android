BEGIN;
DROP FUNCTION IF EXISTS public.founder_payouts_rupees_by_day();
CREATE OR REPLACE FUNCTION public.founder_payouts_rupees_by_day()
RETURNS TABLE (
  day_ist        date,
  processed_cnt  bigint,
  processed_rupees numeric,
  failed_cnt     bigint,
  pending_cnt    bigint
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
    coalesce((SELECT count(*)::bigint FROM public.engineer_payouts p
              WHERE p.status='processed'
                AND (p.queued_at AT TIME ZONE 'Asia/Kolkata')::date = d.day_ist), 0)::bigint,
    coalesce((SELECT round(sum(p.amount_paise)::numeric / 100.0, 2) FROM public.engineer_payouts p
              WHERE p.status='processed'
                AND (p.queued_at AT TIME ZONE 'Asia/Kolkata')::date = d.day_ist), 0)::numeric,
    coalesce((SELECT count(*)::bigint FROM public.engineer_payouts p
              WHERE p.status='failed'
                AND (p.queued_at AT TIME ZONE 'Asia/Kolkata')::date = d.day_ist), 0)::bigint,
    coalesce((SELECT count(*)::bigint FROM public.engineer_payouts p
              WHERE p.status IN ('queued','processing')
                AND (p.queued_at AT TIME ZONE 'Asia/Kolkata')::date = d.day_ist), 0)::bigint
  FROM days d
  ORDER BY d.day_ist DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_payouts_rupees_by_day() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_payouts_rupees_by_day() TO authenticated;
COMMIT;
