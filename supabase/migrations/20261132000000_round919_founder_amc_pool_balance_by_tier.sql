BEGIN;
DROP FUNCTION IF EXISTS public.founder_amc_pool_balance_by_tier();
CREATE OR REPLACE FUNCTION public.founder_amc_pool_balance_by_tier()
RETURNS TABLE (
  tier            text,
  active_contracts bigint,
  total_balance   numeric,
  mrr             numeric,
  avg_buffer_months numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  WITH tiers AS (
    SELECT tier, display_order FROM public.amc_subscription_tiers
  ),
  per_tier AS (
    SELECT c.amc_tier,
           c.id,
           c.monthly_fee_rupees,
           coalesce(b.balance_rupees, 0)::numeric AS balance
    FROM public.amc_contracts c
    LEFT JOIN public.v_amc_pool_balance b ON b.amc_contract_id = c.id
    WHERE c.status = 'active'
  )
  SELECT
    t.tier,
    coalesce((SELECT count(*)::bigint FROM per_tier pt WHERE pt.amc_tier = t.tier), 0)::bigint,
    coalesce((SELECT sum(pt.balance)::numeric FROM per_tier pt WHERE pt.amc_tier = t.tier), 0)::numeric,
    coalesce((SELECT sum(pt.monthly_fee_rupees)::numeric FROM per_tier pt WHERE pt.amc_tier = t.tier), 0)::numeric,
    CASE WHEN coalesce((SELECT sum(pt.monthly_fee_rupees) FROM per_tier pt WHERE pt.amc_tier = t.tier), 0) = 0
         THEN 0::numeric
         ELSE round(
           coalesce((SELECT sum(pt.balance)::numeric FROM per_tier pt WHERE pt.amc_tier = t.tier), 0)
           / coalesce((SELECT sum(pt.monthly_fee_rupees)::numeric FROM per_tier pt WHERE pt.amc_tier = t.tier), 1)
         , 2)
    END
  FROM tiers t
  ORDER BY t.display_order;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_amc_pool_balance_by_tier() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_amc_pool_balance_by_tier() TO authenticated;
COMMIT;
