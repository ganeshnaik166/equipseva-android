BEGIN;
DROP FUNCTION IF EXISTS public.founder_amc_paused_by_tier();
CREATE OR REPLACE FUNCTION public.founder_amc_paused_by_tier()
RETURNS TABLE (
  tier          text,
  paused_cnt    bigint,
  frozen_mrr    numeric,
  avg_days_paused numeric
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
    coalesce((SELECT count(*)::bigint FROM public.amc_contracts c
              WHERE c.status = 'paused' AND c.amc_tier = t.tier), 0)::bigint,
    coalesce((SELECT sum(c.monthly_fee_rupees)::numeric FROM public.amc_contracts c
              WHERE c.status = 'paused' AND c.amc_tier = t.tier), 0)::numeric,
    coalesce((SELECT round(avg(extract(epoch FROM (now() - c.updated_at)) / 86400.0)::numeric, 1)
              FROM public.amc_contracts c
              WHERE c.status = 'paused' AND c.amc_tier = t.tier), 0)::numeric
  FROM tiers t
  ORDER BY t.display_order;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_amc_paused_by_tier() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_amc_paused_by_tier() TO authenticated;
COMMIT;
