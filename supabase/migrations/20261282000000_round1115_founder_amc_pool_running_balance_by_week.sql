BEGIN;
DROP FUNCTION IF EXISTS public.founder_amc_pool_running_balance_by_week();
CREATE OR REPLACE FUNCTION public.founder_amc_pool_running_balance_by_week()
RETURNS TABLE (
  week_start          date,
  net_flow_inr        numeric,
  running_total_inr   numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  WITH weeks AS (
    SELECT generate_series(
      date_trunc('week', now() - interval '12 weeks')::date,
      date_trunc('week', now())::date,
      interval '1 week'
    )::date AS week_start
  ),
  flows AS (
    SELECT
      w.week_start,
      coalesce((SELECT sum(amount_rupees)::numeric FROM public.amc_payment_pool pp
                WHERE pp.ledger_kind = 'credit'
                  AND date_trunc('week', (pp.created_at AT TIME ZONE 'Asia/Kolkata'))::date = w.week_start), 0)
      - coalesce((SELECT sum(amount_rupees)::numeric FROM public.amc_payment_pool pp
                  WHERE pp.ledger_kind IN ('debit','refund')
                    AND date_trunc('week', (pp.created_at AT TIME ZONE 'Asia/Kolkata'))::date = w.week_start), 0)
                                                  AS net_flow_inr
    FROM weeks w
  )
  SELECT
    f.week_start,
    f.net_flow_inr,
    sum(f.net_flow_inr) OVER (ORDER BY f.week_start ASC ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW)::numeric AS running_total_inr
  FROM flows f
  ORDER BY f.week_start DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_amc_pool_running_balance_by_week() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_amc_pool_running_balance_by_week() TO authenticated;
COMMIT;
