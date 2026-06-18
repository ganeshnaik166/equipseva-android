BEGIN;
DROP FUNCTION IF EXISTS public.founder_amc_pool_zero_balance();
CREATE OR REPLACE FUNCTION public.founder_amc_pool_zero_balance()
RETURNS TABLE (
  tier              text,
  total_active_amcs bigint,
  zero_balance_cnt  bigint,
  zero_balance_pct  numeric,
  blocked_mrr_inr   bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  WITH active AS (
    SELECT c.id, c.tier, c.amount_inr,
           coalesce((SELECT balance_rupees FROM public.v_amc_pool_balance v WHERE v.amc_contract_id = c.id), 0)::numeric AS bal
    FROM public.amc_contracts c
    WHERE c.status = 'active'
  )
  SELECT
    coalesce(a.tier, 'unknown')::text                                  AS tier,
    count(*)::bigint                                                    AS total_active_amcs,
    count(*) FILTER (WHERE a.bal <= 0)::bigint                          AS zero_balance_cnt,
    CASE WHEN count(*) = 0 THEN 0::numeric
         ELSE round(100.0 * count(*) FILTER (WHERE a.bal <= 0) / count(*), 1)
    END                                                                  AS zero_balance_pct,
    coalesce(sum(a.amount_inr) FILTER (WHERE a.bal <= 0), 0)::bigint    AS blocked_mrr_inr
  FROM active a
  GROUP BY coalesce(a.tier, 'unknown')
  ORDER BY blocked_mrr_inr DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_amc_pool_zero_balance() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_amc_pool_zero_balance() TO authenticated;
COMMIT;
