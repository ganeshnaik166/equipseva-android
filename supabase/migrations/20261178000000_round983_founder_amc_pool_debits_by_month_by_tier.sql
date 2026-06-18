BEGIN;
DROP FUNCTION IF EXISTS public.founder_amc_pool_debits_by_month_by_tier();
CREATE OR REPLACE FUNCTION public.founder_amc_pool_debits_by_month_by_tier()
RETURNS TABLE (
  month_ist  date,
  tier       text,
  debits     bigint,
  rupees     numeric
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
  tiers AS (
    SELECT tier, display_order FROM public.amc_subscription_tiers
  )
  SELECT
    m.month_ist,
    t.tier,
    coalesce((SELECT count(*)::bigint FROM public.amc_payment_pool pl
              JOIN public.amc_contracts c ON c.id = pl.amc_contract_id
              WHERE pl.ledger_kind = 'debit'
                AND c.amc_tier = t.tier
                AND date_trunc('month', (pl.created_at AT TIME ZONE 'Asia/Kolkata'))::date = m.month_ist), 0)::bigint,
    coalesce((SELECT sum(pl.amount_rupees)::numeric FROM public.amc_payment_pool pl
              JOIN public.amc_contracts c ON c.id = pl.amc_contract_id
              WHERE pl.ledger_kind = 'debit'
                AND c.amc_tier = t.tier
                AND date_trunc('month', (pl.created_at AT TIME ZONE 'Asia/Kolkata'))::date = m.month_ist), 0)::numeric
  FROM months m
  CROSS JOIN tiers t
  ORDER BY m.month_ist DESC, t.display_order;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_amc_pool_debits_by_month_by_tier() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_amc_pool_debits_by_month_by_tier() TO authenticated;
COMMIT;
