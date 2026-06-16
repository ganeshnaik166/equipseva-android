BEGIN;
DROP FUNCTION IF EXISTS public.founder_amc_tier_distribution();
CREATE OR REPLACE FUNCTION public.founder_amc_tier_distribution()
RETURNS TABLE (
  tier            text,
  active_cnt      bigint,
  total_cnt       bigint,
  monthly_mrr     numeric,
  avg_fee         numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  WITH tiers AS (
    SELECT tier, display_order FROM public.amc_subscription_tiers
  )
  SELECT
    t.tier,
    coalesce(count(*) FILTER (WHERE c.status = 'active'), 0)::bigint,
    coalesce(count(c.id), 0)::bigint,
    coalesce(sum(c.monthly_fee_rupees) FILTER (WHERE c.status = 'active'), 0)::numeric,
    CASE WHEN count(*) FILTER (WHERE c.status = 'active') = 0 THEN 0::numeric
         ELSE round(
           sum(c.monthly_fee_rupees) FILTER (WHERE c.status = 'active')::numeric
           / count(*) FILTER (WHERE c.status = 'active')::numeric,
           2)
    END
  FROM tiers t
  LEFT JOIN public.amc_contracts c ON c.amc_tier = t.tier
  GROUP BY t.tier, t.display_order
  ORDER BY t.display_order;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_amc_tier_distribution() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_amc_tier_distribution() TO authenticated;
COMMIT;
