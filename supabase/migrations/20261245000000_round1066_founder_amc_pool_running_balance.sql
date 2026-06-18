BEGIN;
DROP FUNCTION IF EXISTS public.founder_amc_pool_running_balance();
CREATE OR REPLACE FUNCTION public.founder_amc_pool_running_balance()
RETURNS TABLE (
  month_ist        date,
  net_flow_inr     numeric,
  running_total_inr numeric
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
  ),
  flows AS (
    SELECT
      m.month_ist,
      coalesce((SELECT sum(amount_rupees)::numeric FROM public.amc_payment_pool pp
                WHERE pp.ledger_kind = 'credit'
                  AND date_trunc('month', (pp.created_at AT TIME ZONE 'Asia/Kolkata'))::date = m.month_ist), 0)
      - coalesce((SELECT sum(amount_rupees)::numeric FROM public.amc_payment_pool pp
                  WHERE pp.ledger_kind IN ('debit','refund')
                    AND date_trunc('month', (pp.created_at AT TIME ZONE 'Asia/Kolkata'))::date = m.month_ist), 0)
                                                AS net_flow_inr
    FROM months m
  )
  SELECT
    f.month_ist,
    f.net_flow_inr,
    sum(f.net_flow_inr) OVER (ORDER BY f.month_ist ASC ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW)::numeric
                                                AS running_total_inr
  FROM flows f
  ORDER BY f.month_ist DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_amc_pool_running_balance() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_amc_pool_running_balance() TO authenticated;
COMMIT;
