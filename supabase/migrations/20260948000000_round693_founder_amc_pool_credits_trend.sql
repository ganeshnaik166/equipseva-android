BEGIN;
DROP FUNCTION IF EXISTS public.founder_amc_pool_credits_trend();
CREATE OR REPLACE FUNCTION public.founder_amc_pool_credits_trend()
RETURNS TABLE (
  day_ist        date,
  credit_rupees  numeric,
  debit_rupees   numeric,
  refund_rupees  numeric,
  events         bigint
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
      (SELECT sum(p.amount_rupees)::numeric FROM public.amc_payment_pool p
       WHERE p.ledger_kind = 'credit'
         AND (p.created_at AT TIME ZONE 'Asia/Kolkata')::date = d.day_ist
      ), 0)::numeric,
    coalesce(
      (SELECT sum(p.amount_rupees)::numeric FROM public.amc_payment_pool p
       WHERE p.ledger_kind = 'debit'
         AND (p.created_at AT TIME ZONE 'Asia/Kolkata')::date = d.day_ist
      ), 0)::numeric,
    coalesce(
      (SELECT sum(p.amount_rupees)::numeric FROM public.amc_payment_pool p
       WHERE p.ledger_kind = 'refund'
         AND (p.created_at AT TIME ZONE 'Asia/Kolkata')::date = d.day_ist
      ), 0)::numeric,
    coalesce(
      (SELECT count(*)::bigint FROM public.amc_payment_pool p
       WHERE (p.created_at AT TIME ZONE 'Asia/Kolkata')::date = d.day_ist
      ), 0)::bigint
  FROM days d
  ORDER BY d.day_ist DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_amc_pool_credits_trend() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_amc_pool_credits_trend() TO authenticated;
COMMIT;
