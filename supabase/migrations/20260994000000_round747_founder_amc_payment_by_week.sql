BEGIN;
DROP FUNCTION IF EXISTS public.founder_amc_payment_by_week();
CREATE OR REPLACE FUNCTION public.founder_amc_payment_by_week()
RETURNS TABLE (
  week_start   date,
  paid_count   bigint,
  paid_rupees  numeric,
  failed_count bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  WITH weeks AS (
    SELECT generate_series(
      date_trunc('week', (now() AT TIME ZONE 'Asia/Kolkata')::date - interval '12 weeks'),
      date_trunc('week', (now() AT TIME ZONE 'Asia/Kolkata')::date),
      interval '1 week'
    )::date AS week_start
  )
  SELECT
    w.week_start,
    coalesce((SELECT count(*)::bigint FROM public.amc_payment_orders o
              WHERE o.status = 'paid'
                AND date_trunc('week', (o.updated_at AT TIME ZONE 'Asia/Kolkata'))::date = w.week_start), 0)::bigint,
    coalesce((SELECT sum(o.amount_rupees)::numeric FROM public.amc_payment_orders o
              WHERE o.status = 'paid'
                AND date_trunc('week', (o.updated_at AT TIME ZONE 'Asia/Kolkata'))::date = w.week_start), 0)::numeric,
    coalesce((SELECT count(*)::bigint FROM public.amc_payment_orders o
              WHERE o.status = 'failed'
                AND date_trunc('week', (o.updated_at AT TIME ZONE 'Asia/Kolkata'))::date = w.week_start), 0)::bigint
  FROM weeks w
  ORDER BY w.week_start DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_amc_payment_by_week() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_amc_payment_by_week() TO authenticated;
COMMIT;
