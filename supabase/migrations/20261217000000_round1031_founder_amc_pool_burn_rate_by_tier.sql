BEGIN;
DROP FUNCTION IF EXISTS public.founder_amc_pool_burn_rate_by_tier();
CREATE OR REPLACE FUNCTION public.founder_amc_pool_burn_rate_by_tier()
RETURNS TABLE (
  tier                       text,
  active_amcs                bigint,
  total_balance_inr          numeric,
  debits_last_30d_inr        numeric,
  avg_monthly_burn_per_amc   numeric,
  est_months_to_zero         numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  WITH active AS (
    SELECT c.id, coalesce(c.tier, 'unknown')::text AS tier,
           coalesce((SELECT balance_rupees FROM public.v_amc_pool_balance v WHERE v.amc_contract_id = c.id), 0)::numeric AS bal
    FROM public.amc_contracts c
    WHERE c.status = 'active'
  ),
  debits AS (
    SELECT coalesce(c.tier, 'unknown')::text AS tier,
           sum(pp.amount_rupees)::numeric AS debit_inr
    FROM public.amc_payment_pool pp
    JOIN public.amc_contracts c ON c.id = pp.amc_contract_id
    WHERE pp.ledger_kind = 'debit'
      AND pp.created_at >= now() - interval '30 days'
    GROUP BY coalesce(c.tier, 'unknown')
  )
  SELECT
    a.tier,
    count(*)::bigint                                                 AS active_amcs,
    sum(a.bal)::numeric                                              AS total_balance_inr,
    coalesce(d.debit_inr, 0)::numeric                                AS debits_last_30d_inr,
    CASE WHEN count(*) = 0 THEN 0::numeric
         ELSE round(coalesce(d.debit_inr, 0)::numeric / count(*), 2)
    END                                                              AS avg_monthly_burn_per_amc,
    CASE
      WHEN coalesce(d.debit_inr, 0) = 0 THEN 0::numeric
      ELSE round(sum(a.bal)::numeric / coalesce(d.debit_inr, 1), 1)
    END                                                              AS est_months_to_zero
  FROM active a
  LEFT JOIN debits d ON d.tier = a.tier
  GROUP BY a.tier, d.debit_inr
  ORDER BY est_months_to_zero ASC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_amc_pool_burn_rate_by_tier() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_amc_pool_burn_rate_by_tier() TO authenticated;
COMMIT;
