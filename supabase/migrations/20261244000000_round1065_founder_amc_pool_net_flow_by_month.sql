BEGIN;
DROP FUNCTION IF EXISTS public.founder_amc_pool_net_flow_by_month();
CREATE OR REPLACE FUNCTION public.founder_amc_pool_net_flow_by_month()
RETURNS TABLE (
  month_ist        date,
  credits_inr      numeric,
  debits_inr       numeric,
  refunds_inr      numeric,
  net_flow_inr     numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  WITH months AS (
    SELECT generate_series(
      date_trunc('month', now() - interval '5 months')::date,
      date_trunc('month', now())::date,
      interval '1 month'
    )::date AS month_ist
  )
  SELECT
    m.month_ist,
    coalesce((SELECT sum(amount_rupees)::numeric FROM public.amc_payment_pool pp
              WHERE pp.ledger_kind = 'credit'
                AND date_trunc('month', (pp.created_at AT TIME ZONE 'Asia/Kolkata'))::date = m.month_ist), 0)   AS credits_inr,
    coalesce((SELECT sum(amount_rupees)::numeric FROM public.amc_payment_pool pp
              WHERE pp.ledger_kind = 'debit'
                AND date_trunc('month', (pp.created_at AT TIME ZONE 'Asia/Kolkata'))::date = m.month_ist), 0)   AS debits_inr,
    coalesce((SELECT sum(amount_rupees)::numeric FROM public.amc_payment_pool pp
              WHERE pp.ledger_kind = 'refund'
                AND date_trunc('month', (pp.created_at AT TIME ZONE 'Asia/Kolkata'))::date = m.month_ist), 0)   AS refunds_inr,
    coalesce((SELECT sum(amount_rupees)::numeric FROM public.amc_payment_pool pp
              WHERE pp.ledger_kind = 'credit'
                AND date_trunc('month', (pp.created_at AT TIME ZONE 'Asia/Kolkata'))::date = m.month_ist), 0)
    - coalesce((SELECT sum(amount_rupees)::numeric FROM public.amc_payment_pool pp
                WHERE pp.ledger_kind IN ('debit','refund')
                  AND date_trunc('month', (pp.created_at AT TIME ZONE 'Asia/Kolkata'))::date = m.month_ist), 0) AS net_flow_inr
  FROM months m
  ORDER BY m.month_ist DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_amc_pool_net_flow_by_month() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_amc_pool_net_flow_by_month() TO authenticated;
COMMIT;
