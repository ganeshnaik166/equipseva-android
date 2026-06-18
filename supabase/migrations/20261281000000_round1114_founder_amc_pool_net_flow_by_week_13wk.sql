BEGIN;
DROP FUNCTION IF EXISTS public.founder_amc_pool_net_flow_by_week_13wk();
CREATE OR REPLACE FUNCTION public.founder_amc_pool_net_flow_by_week_13wk()
RETURNS TABLE (
  week_start       date,
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
  WITH weeks AS (
    SELECT generate_series(
      date_trunc('week', now() - interval '12 weeks')::date,
      date_trunc('week', now())::date,
      interval '1 week'
    )::date AS week_start
  )
  SELECT
    w.week_start,
    coalesce((SELECT sum(amount_rupees)::numeric FROM public.amc_payment_pool pp
              WHERE pp.ledger_kind = 'credit'
                AND date_trunc('week', (pp.created_at AT TIME ZONE 'Asia/Kolkata'))::date = w.week_start), 0)              AS credits_inr,
    coalesce((SELECT sum(amount_rupees)::numeric FROM public.amc_payment_pool pp
              WHERE pp.ledger_kind = 'debit'
                AND date_trunc('week', (pp.created_at AT TIME ZONE 'Asia/Kolkata'))::date = w.week_start), 0)              AS debits_inr,
    coalesce((SELECT sum(amount_rupees)::numeric FROM public.amc_payment_pool pp
              WHERE pp.ledger_kind = 'refund'
                AND date_trunc('week', (pp.created_at AT TIME ZONE 'Asia/Kolkata'))::date = w.week_start), 0)              AS refunds_inr,
    coalesce((SELECT sum(amount_rupees)::numeric FROM public.amc_payment_pool pp
              WHERE pp.ledger_kind = 'credit'
                AND date_trunc('week', (pp.created_at AT TIME ZONE 'Asia/Kolkata'))::date = w.week_start), 0)
    - coalesce((SELECT sum(amount_rupees)::numeric FROM public.amc_payment_pool pp
                WHERE pp.ledger_kind IN ('debit','refund')
                  AND date_trunc('week', (pp.created_at AT TIME ZONE 'Asia/Kolkata'))::date = w.week_start), 0)            AS net_flow_inr
  FROM weeks w
  ORDER BY w.week_start DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_amc_pool_net_flow_by_week_13wk() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_amc_pool_net_flow_by_week_13wk() TO authenticated;
COMMIT;
