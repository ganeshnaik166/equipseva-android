BEGIN;
DROP FUNCTION IF EXISTS public.founder_amc_pool_credits_source();
CREATE OR REPLACE FUNCTION public.founder_amc_pool_credits_source()
RETURNS TABLE (
  month_ist     date,
  credit_rupees numeric,
  debit_rupees  numeric,
  refund_rupees numeric,
  net_rupees    numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  WITH months AS (
    SELECT generate_series(
      date_trunc('month', now() - interval '11 months')::date,
      date_trunc('month', now())::date,
      interval '1 month'
    )::date AS month_ist
  )
  SELECT
    m.month_ist,
    coalesce((SELECT sum(p.amount_rupees)::numeric FROM public.amc_payment_pool p
              WHERE p.ledger_kind='credit'
                AND date_trunc('month', (p.created_at AT TIME ZONE 'Asia/Kolkata'))::date = m.month_ist), 0)::numeric,
    coalesce((SELECT sum(p.amount_rupees)::numeric FROM public.amc_payment_pool p
              WHERE p.ledger_kind='debit'
                AND date_trunc('month', (p.created_at AT TIME ZONE 'Asia/Kolkata'))::date = m.month_ist), 0)::numeric,
    coalesce((SELECT sum(p.amount_rupees)::numeric FROM public.amc_payment_pool p
              WHERE p.ledger_kind='refund'
                AND date_trunc('month', (p.created_at AT TIME ZONE 'Asia/Kolkata'))::date = m.month_ist), 0)::numeric,
    coalesce((SELECT sum(CASE WHEN p.ledger_kind='credit' THEN p.amount_rupees ELSE -p.amount_rupees END)::numeric FROM public.amc_payment_pool p
              WHERE date_trunc('month', (p.created_at AT TIME ZONE 'Asia/Kolkata'))::date = m.month_ist), 0)::numeric
  FROM months m
  ORDER BY m.month_ist DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_amc_pool_credits_source() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_amc_pool_credits_source() TO authenticated;
COMMIT;
