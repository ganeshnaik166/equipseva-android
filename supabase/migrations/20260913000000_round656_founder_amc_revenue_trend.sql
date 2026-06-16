BEGIN;
DROP FUNCTION IF EXISTS public.founder_amc_revenue_trend();
CREATE OR REPLACE FUNCTION public.founder_amc_revenue_trend()
RETURNS TABLE (
  day_ist        date,
  paid_orders    bigint,
  rupees_paid    numeric,
  failed_orders  bigint
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
      (SELECT count(*)::bigint FROM public.amc_payment_orders o
       WHERE o.status = 'paid'
         AND (o.updated_at AT TIME ZONE 'Asia/Kolkata')::date = d.day_ist
      ), 0)::bigint AS paid_orders,
    coalesce(
      (SELECT sum(o.amount_rupees)::numeric FROM public.amc_payment_orders o
       WHERE o.status = 'paid'
         AND (o.updated_at AT TIME ZONE 'Asia/Kolkata')::date = d.day_ist
      ), 0)::numeric AS rupees_paid,
    coalesce(
      (SELECT count(*)::bigint FROM public.amc_payment_orders o
       WHERE o.status = 'failed'
         AND (o.updated_at AT TIME ZONE 'Asia/Kolkata')::date = d.day_ist
      ), 0)::bigint AS failed_orders
  FROM days d
  ORDER BY d.day_ist DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_amc_revenue_trend() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_amc_revenue_trend() TO authenticated;
COMMIT;
